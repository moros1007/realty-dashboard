# ============================================================================
#  send_kakao.ps1  —  카카오톡 '나에게 보내기' 로 오늘의 시세 요약 카드 발송
#  · kakao_token.json 의 refresh_token 으로 access_token 자동 갱신
#  · data/latest.json 을 요약해 feed 카드(+[대시보드 전체 보기] 버튼) 전송
#  · -DryRun : 토큰/발송 없이 보낼 내용만 미리보기(테스트용)
# ============================================================================
param([switch]$DryRun)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = Get-Content -Raw -Encoding UTF8 (Join-Path $ScriptDir 'config.json') | ConvertFrom-Json
$jsonPath = Join-Path $ScriptDir 'data\latest.json'
if (-not (Test-Path $jsonPath)) {
  Write-Host "  ⚠ data/latest.json 이 없습니다. 먼저 '① 시세 업데이트.bat' 을 실행하세요." -ForegroundColor Yellow; exit 1
}
$d = Get-Content -Raw -Encoding UTF8 $jsonPath | ConvertFrom-Json
$cap = [double]$d.config.priceMaxEok
$items = @($d.items)

# 대시보드 주소 (미설정 시 네이버 검색으로 대체)
$url = "$($cfg.dashboardUrl)"
if ([string]::IsNullOrWhiteSpace($url) -or $url -like '*<*') {
  $url = 'https://search.naver.com/search.naver?query=' + [uri]::EscapeDataString('분당 평촌 과천 아파트 매매')
  Write-Host "  ⚠ config.dashboardUrl 미설정 → 버튼을 네이버 검색으로 임시 연결합니다." -ForegroundColor Yellow
}

function Median([double[]]$a) { if (-not $a -or $a.Count -eq 0) { return 0 } $s = $a | Sort-Object; $m = [int][math]::Floor($s.Count / 2); if ($s.Count % 2) { $s[$m] } else { ($s[$m - 1] + $s[$m]) / 2 } }
function Eok([double]$manwon) { [math]::Round($manwon / 10000, 1) }

# 지역별 요약 항목
$regionItems = @()
foreach ($rg in @('분당', '평촌', '과천')) {
  $g = @($items | Where-Object { $_.region -eq $rg })
  if ($g.Count -eq 0) { continue }
  $under = @($g | Where-Object { $_.amountManwon -le $cap * 10000 })
  $med = Eok (Median ([double[]]($g | ForEach-Object { $_.amountManwon })))
  $op = if ($under.Count -gt 0) { "예산내 $($under.Count)건 · 중앙 ${med}억" } else { "예산초과 · 중앙 ${med}억" }
  $regionItems += @{ item = $rg; item_op = $op }
}

# 내 집 평균 매도가 / 신규 / 예산내 최저가
$my = @($d.myHome.items)
$myEok = if ($my.Count) { Eok (($my | Measure-Object amountManwon -Average).Average) } else { 0 }
$newCount = [int]$d.newCount
# 예산내 최저가 — 지분·가족 직거래 등 '이상 저가'를 빼기 위해 지역 중앙값의 60% 미만은 후보 제외
$cheap = $null
foreach ($rg in @('분당', '평촌', '과천')) {
  $g = @($items | Where-Object { $_.region -eq $rg }); if ($g.Count -eq 0) { continue }
  $rmed = Median ([double[]]($g | ForEach-Object { $_.amountManwon }))
  $cand = @($g | Where-Object { $_.amountManwon -le $cap * 10000 -and $_.amountManwon -ge $rmed * 0.6 } | Sort-Object amountManwon | Select-Object -First 1)
  if ($cand.Count -and (-not $cheap -or $cand[0].amountManwon -lt $cheap.amountManwon)) { $cheap = $cand[0] }
}
$cheapLine = if ($cheap) { "예산내 최저가 $($cheap.region) $($cheap.apt) $(Eok $cheap.amountManwon)억" } else { '예산내 매물 없음' }

# ── 자금 요약(대시보드 계산기와 동일 로직, 84㎡=농특 면제·1주택 가정) ──
function EokS($man) { if ([math]::Abs($man) / 10000 -ge 1) { ('{0}억' -f ([math]::Round($man / 10000, 1))) } else { ('{0:N0}만' -f [math]::Round($man)) } }
function Broker($man) { $e = $man / 10000; $r = if ($e -lt 2) { 0.005 } elseif ($e -lt 9) { 0.004 } elseif ($e -lt 12) { 0.005 } elseif ($e -lt 15) { 0.006 } else { 0.007 }; return $man * $r }
$fn = $cfg.funds
if ($fn) {
  $buyMan = [double]($fn.buyEok) * 10000
  $sellMan = if ($my.Count) { ($my | Measure-Object amountManwon -Average).Average } else { 0 }
  $e = $buyMan / 10000; $arate = if ($e -le 6) { 1 } elseif ($e -le 9) { $e * 2 / 3 - 3 } else { 3 }
  $acq = $buyMan * $arate / 100 * 1.1                         # 취득세+지방교육세
  $buyCost = $acq + (Broker $buyMan) + ($buyMan * 0.0015 + 30)
  $sellNet = if ($sellMan -gt 0) { $sellMan - (Broker $sellMan) } else { 0 }
  $need = [math]::Max(0, ($buyMan + $buyCost) - $sellNet)
  $reg = [bool]$fn.regulated
  $ltvLim = $buyMan * $(if ($reg) { 50 } else { 70 }) / 100
  $loanCap = if ($reg) { if ($e -le 15) { 60000 } elseif ($e -le 25) { 40000 } else { 20000 } } else { 1e9 }
  $rate = [double]$fn.loanRatePct; $yrs = [int]$fn.loanYears; $ii = ($rate + [double]$fn.stressAddPct) / 100 / 12; $nn = $yrs * 12
  $monthAllow = [double]($fn.annualIncomeManwon) * 0.4 / 12
  $dsrLim = if ($ii -le 0) { $monthAllow * $nn } else { $monthAllow * (1 - [math]::Pow(1 + $ii, -$nn)) / $ii }
  $maxLoan = [math]::Min([math]::Min($ltvLim, $loanCap), $dsrLim)
  $iL = $rate / 100 / 12; $monthly = if ($iL -le 0) { $need / $nn } else { $need * $iL / (1 - [math]::Pow(1 + $iL, -$nn)) }
  $okTxt = if ($need -le $maxLoan + 1) { '가능' } else { ('부족 {0:N0}만' -f ($need - $maxLoan)) }
  $regionItems += @{ item = '💸자금'; item_op = ("{0} 매수: 대출 {1}(한도 {2})·월 {3:N0}만·{4}" -f (EokS $buyMan), (EokS $need), (EokS $maxLoan), [math]::Round($monthly), $okTxt) }
}

# ── 관심단지 우선알림(신규 거래 중 watch 일치) ──
$watch = @($cfg.watch | Where-Object { "$_".Trim() })
if ($watch.Count -gt 0) {
  $hits = @($items | Where-Object { $_.isNew -eq $true } | Where-Object { $a = "$($_.apt)"; @($watch | Where-Object { $a -like "*$_*" }).Count -gt 0 })
  if ($hits.Count -gt 0) {
    $h0 = $hits[0]
    $wOp = if ($hits.Count -gt 1) { "{0} {1} 외 {2}건 NEW" -f $h0.apt, (EokS $h0.amountManwon), ($hits.Count - 1) } else { "{0} {1} NEW" -f $h0.apt, (EokS $h0.amountManwon) }
    $regionItems = , @{ item = '⭐관심'; item_op = $wOp } + $regionItems    # 맨 위로
  }
}

$today = (Get-Date).ToString('M월 d일')
$newPart = if ($newCount -gt 0) { " · 신규 ${newCount}건" } else { '' }
$desc = "30평형대(전용84㎡) · 예산 ${cap}억 이하`n내 집 매도가 ≈ ${myEok}억${newPart}`n${cheapLine}"

$template = @{
  object_type = 'feed'
  content     = @{
    title = "🏠 $today 분당·평촌·과천 시세"
    description = $desc
    link  = @{ web_url = $url; mobile_web_url = $url }
  }
  item_content = @{ items = $regionItems }
  buttons     = @( @{ title = '📊 대시보드 전체 보기'; link = @{ web_url = $url; mobile_web_url = $url } } )
}
$templateJson = $template | ConvertTo-Json -Depth 10 -Compress

if ($DryRun) {
  Write-Host ""
  Write-Host "  ── [DryRun] 보낼 카드 내용 미리보기 ──────────────" -ForegroundColor Cyan
  Write-Host "  제목 : $($template.content.title)"
  Write-Host "  설명 : " -NoNewline; ($desc -split "`n") | ForEach-Object { Write-Host "         $_" }
  Write-Host "  항목 :"; $regionItems | ForEach-Object { Write-Host "         - $($_.item) : $($_.item_op)" }
  Write-Host "  버튼 : 📊 대시보드 전체 보기 → $url"
  Write-Host "  (실제 발송은 -DryRun 없이 실행)" -ForegroundColor DarkGray
  Write-Host ""
  exit 0
}

# ── 토큰 갱신 ──────────────────────────────────────────────────────────────
$tokPath = Join-Path $ScriptDir 'kakao_token.json'
if (-not (Test-Path $tokPath)) { Write-Host "  ⚠ 먼저 '카카오 연결.bat' 으로 연결하세요." -ForegroundColor Yellow; exit 1 }
$tok = Get-Content -Raw -Encoding UTF8 $tokPath | ConvertFrom-Json
$rest = "$($cfg.kakao.restApiKey)"
$rbody = @{ grant_type = 'refresh_token'; client_id = $rest; refresh_token = "$($tok.refresh_token)" }
$sec = "$($cfg.kakao.clientSecret)"
if (-not [string]::IsNullOrWhiteSpace($sec) -and $sec -notlike '*<*') { $rbody['client_secret'] = $sec }
try {
  $ref = Invoke-RestMethod -Uri 'https://kauth.kakao.com/oauth/token' -Method Post -Body $rbody
} catch { Write-Host "  ✖ 토큰 갱신 실패: $($_.Exception.Message). '카카오 연결.bat' 으로 재연결하세요." -ForegroundColor Red; exit 1 }
$access = "$($ref.access_token)"
$tok.access_token = $access
if ($ref.refresh_token) { $tok | Add-Member refresh_token "$($ref.refresh_token)" -Force }
$tok | Add-Member updated (Get-Date -Format 'yyyy-MM-dd HH:mm') -Force
$tok | ConvertTo-Json | Set-Content -Encoding UTF8 $tokPath

# ── 발송 ───────────────────────────────────────────────────────────────────
try {
  $res = Invoke-RestMethod -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' -Method Post `
    -Headers @{ Authorization = "Bearer $access" } -Body @{ template_object = $templateJson }
  if ("$($res.result_code)" -eq '0') { Write-Host "  ✓ 카카오톡 발송 완료 ($today)" -ForegroundColor Green }
  else { Write-Host "  ? 응답: $($res | ConvertTo-Json -Compress)" -ForegroundColor Yellow }
} catch {
  Write-Host "  ✖ 발송 실패: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "    카카오 앱의 talk_message 동의항목이 켜져 있는지, 토큰이 유효한지 확인하세요." -ForegroundColor Yellow
  exit 1
}
