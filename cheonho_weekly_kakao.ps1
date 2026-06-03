# ============================================================================
#  cheonho_weekly_kakao.ps1 — 천호 접근 5억 매물 '주간 요약' 생성 + 카카오톡 발송
#  ──────────────────────────────────────────────────────────────────────────
#  · data/cheonho.json 을 큐레이션 → data/cheonho_weekly.(js|json) 생성
#    (주간 요약 페이지 cheonho_weekly.html 과 카톡 카드가 함께 사용)
#  · 카카오톡 '나에게 보내기'(memo) 로 요약 카드 전송 → 가족·지인에게 '전달'
#  · -DryRun : 토큰/발송 없이 요약 데이터만 생성하고 카드 내용 미리보기
#  사용: '⑦ 주간 카톡 요약 보내기.bat'  /  powershell -File cheonho_weekly_kakao.ps1 [-DryRun]
# ============================================================================
param([switch]$DryRun)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir   = Join-Path $ScriptDir 'data'
$cfg = Get-Content -Raw -Encoding UTF8 (Join-Path $ScriptDir 'config.json') | ConvertFrom-Json
$ch  = $cfg.cheonho
$capEok = if ($ch -and $ch.capEok) { [double]$ch.capEok } else { 5 }
$capManwon = $capEok * 10000

$srcPath = Join-Path $DataDir 'cheonho.json'
if (-not (Test-Path $srcPath)) {
  Write-Host "  ⚠ data/cheonho.json 이 없습니다. 먼저 '⑤ 천호 역세권 업데이트.bat' 을 실행하세요." -ForegroundColor Yellow; exit 1
}
$d = Get-Content -Raw -Encoding UTF8 $srcPath | ConvertFrom-Json
$items = @($d.items)

# ── 요약용 동(洞) → 천호분/지형/역 (cheonho.html STATION 의 핵심 부분) ───────────
$DONG = @{
  '천호동'=@{min=0; terr='평지'; st='천호역'};      '성내동'=@{min=2; terr='평지'; st='강동구청역'}
  '풍납동'=@{min=4; terr='평지'; st='천호역'};        '둔촌동'=@{min=6; terr='평지'; st='둔촌동역'}
  '수택동'=@{min=12;terr='평지'; st='구리역'};        '인창동'=@{min=11;terr='완경사'; st='구리역'}
  '교문동'=@{min=13;terr='완경사';st='구리역'};        '지금동'=@{min=15;terr='평지'; st='다산역'}
  '다산동'=@{min=15;terr='평지'; st='다산역'};        '도농동'=@{min=15;terr='평지'; st='다산역'}
  '가운동'=@{min=16;terr='평지'; st='다산역'};        '별내동'=@{min=18;terr='평지'; st='별내역'}
}
function DongMin($u){ if ($DONG.ContainsKey($u)) { $DONG[$u].min } else { 99 } }
function DongTerr($u){ if ($DONG.ContainsKey($u)) { $DONG[$u].terr } else { '확인' } }
function DongSt($u){ if ($DONG.ContainsKey($u)) { $DONG[$u].st } else { '확인필요' } }
function IsRegulated($code){ $c="$code"; return ($c.Substring(0,2) -eq '11' -or @('41131','41133','41135') -contains $c) }
function Median([double[]]$a){ if(-not $a -or $a.Count -eq 0){return 0}; $s=$a|Sort-Object; $m=[int][math]::Floor($s.Count/2); if($s.Count%2){$s[$m]}else{($s[$m-1]+$s[$m])/2} }
function Eok1($m){ [math]::Round($m/10000,1) }
$flatDong = @('수택동','지금동','다산동','도농동','가운동','별내동')

# ── (A) 이번 주 추천: 별내선 평지 · 전용 55㎡↑ · 매매 5억선(전세끼고 3~4년 가능) ──
$bandMan  = $capManwon + 5000     # '5억선' = +0.5억 여유
$floorMan = 35000                 # 과저가(복도식·초소형) 제외
$gangNear = @('천호동','성내동','풍납동','둔촌동')   # 강동 평지(천호 인접)
$pickRaw = $items | Where-Object {
  $_.group -eq '별내선' -and $flatDong -contains $_.umd -and
  $_.areaM2 -ge 55 -and $_.amountManwon -ge $floorMan -and $_.amountManwon -le $bandMan
} | Sort-Object @{Expression='buildYear';Descending=$true}, amountManwon
# 같은 단지 중복 제거(단지명 기준 1건)
$seen=@{}; $picksAll=@()
foreach($p in $pickRaw){ if(-not $seen.ContainsKey($p.apt)){ $seen[$p.apt]=$true
  $picksAll += [ordered]@{ region=$p.region; apt=$p.apt; umd=$p.umd; areaM2=$p.areaM2; floor=$p.floor; buildYear=$p.buildYear;
    priceEok=Eok1 $p.amountManwon; jeonseEok=Eok1 $p.jeonseManwon; gapEok=Eok1 $p.gapManwon;
    st=DongSt $p.umd; min=DongMin $p.umd; terr=DongTerr $p.umd; strategy='전세끼고' } } }
$pickPoolN = $picksAll.Count          # 별내선 평지 매매5억선 추천 후보(단지) 수
$picks = @($picksAll | Select-Object -First 8)

# ── (B) 천호 코앞 강동(천호·성내·풍납·둔촌) 즉시 실입주: 매매 5억선 ───────────────
$liveRaw = $items | Where-Object { $_.group -eq '강동' -and $gangNear -contains $_.umd -and $_.areaM2 -ge 49 -and $_.amountManwon -ge $floorMan -and $_.amountManwon -le $bandMan } | Sort-Object @{Expression='buildYear';Descending=$true}, amountManwon
$seen2=@{}; $liveIn=@()
foreach($p in $liveRaw){ if(-not $seen2.ContainsKey($p.apt)){ $seen2[$p.apt]=$true
  $liveIn += [ordered]@{ region=$p.region; apt=$p.apt; umd=$p.umd; areaM2=$p.areaM2; buildYear=$p.buildYear;
    priceEok=Eok1 $p.amountManwon; jeonseEok=Eok1 $p.jeonseManwon; st=DongSt $p.umd; min=DongMin $p.umd; strategy='실입주' } } }
$liveIn = @($liveIn | Select-Object -First 6)

# ── (C) 그룹 비교 통계 (매매 5억선 단지 수) ───────────────────────────────────
$groups=@()
foreach($g in @('별내선','강동','송파','성남','분당')){
  $arrG=@($items | Where-Object { $_.group -eq $g }); if($arrG.Count -eq 0){continue}
  $reg=IsRegulated $arrG[0].code
  $groups += [ordered]@{
    group=$g; regulated=$reg
    saleMedEok = Eok1 (Median ([double[]]($arrG | %{ $_.amountManwon })))
    gapMedEok  = Eok1 (Median ([double[]]($arrG | %{ [double]$_.gapManwon })))
    gapFit     = @($arrG | Where-Object { $_.amountManwon -le $bandMan } | Select-Object -ExpandProperty apt -Unique).Count
    count      = $arrG.Count
  }
}

# ── 요약 객체 → cheonho_weekly.(js|json) ────────────────────────────────────
$byeollaeFit = [int]$pickPoolN   # 추천 후보(별내선 평지 84㎡ 갭5억↓) 단지 수
$weekLabel = (Get-Date).ToString('yyyy년 M월 d일')
$summary = [ordered]@{
  generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  weekLabel   = $weekLabel
  capEok      = $capEok
  dataUpdated = "$($d.updatedAt)"
  shareUrl    = "$($ch.shareUrl)"
  fullUrl     = "$($cfg.dashboardUrl)"
  byeollaeFit = [int]$byeollaeFit
  picks       = $picks
  liveIn      = $liveIn
  groups      = $groups
}
$json = $summary | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText((Join-Path $DataDir 'cheonho_weekly.js'),
  "/* 자동 생성 — '⑦ 주간 카톡 요약 보내기.bat' 실행 시 갱신 */`r`nwindow.CHEONHO_WEEKLY = $json;`r`n",
  (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText((Join-Path $DataDir 'cheonho_weekly.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  ✓ 주간 요약 데이터 생성: data/cheonho_weekly.js (추천 $($picks.Count)건)" -ForegroundColor Green

# ── 카카오 카드(feed) 구성 ──────────────────────────────────────────────────
$shareUrl = "$($ch.shareUrl)"
if ([string]::IsNullOrWhiteSpace($shareUrl) -or $shareUrl -like '*<*') { $shareUrl = "$($cfg.dashboardUrl)" }
if ([string]::IsNullOrWhiteSpace($shareUrl) -or $shareUrl -like '*<*') { $shareUrl = 'https://search.naver.com/search.naver?query=' + [uri]::EscapeDataString('다산신도시 별내 아파트 매매') }
# 분당·평촌·과천 카드처럼 '대시보드 전체 보기' → 천호 전체 분석 대시보드(cheonho.html)
$fullUrl = ("$($cfg.dashboardUrl)").TrimEnd('/') + '/cheonho.html'
if ([string]::IsNullOrWhiteSpace("$($cfg.dashboardUrl)") -or "$($cfg.dashboardUrl)" -like '*<*') { $fullUrl = $shareUrl }

$cardItems = @()
foreach($p in (@($picks | Select-Object -First 3))){
  $cardItems += @{ item = ("별내선 {0}" -f $p.apt); item_op = ("{0}㎡ 매매{1}억·천호{2}분·전세끼고" -f [int][math]::Floor([double]$p.areaM2), $p.priceEok, $p.min) }
}
foreach($p in (@($liveIn | Select-Object -First 2))){
  $cardItems += @{ item = ("강동 {0}" -f $p.apt); item_op = ("{0}㎡ 매매{1}억·천호{2}분·실입주" -f [int][math]::Floor([double]$p.areaM2), $p.priceEok, $p.min) }
}

$desc = "매매 ${capEok}억선 · 천호 접근 · 어르신 평지`n천호 코앞 강동: 5억대 실입주 가능(토허라 전세끼고 불가)`n전세끼고 3~4년: 비규제 별내선(다산·별내·평지)`n별내선 매매5억선 평지 ${byeollaeFit}곳"
$template = @{
  object_type = 'feed'
  content = @{
    title = "🏠 [주간] 천호 접근 ${capEok}억 매물 요약 ($weekLabel)"
    description = $desc
    link = @{ web_url=$fullUrl; mobile_web_url=$fullUrl }
  }
  item_content = @{ items = $cardItems }
  buttons = @(
    @{ title='📊 대시보드 전체 보기'; link=@{ web_url=$fullUrl; mobile_web_url=$fullUrl } }
  )
}
$templateJson = $template | ConvertTo-Json -Depth 10 -Compress

if ($DryRun) {
  Write-Host ""
  Write-Host "  ── [DryRun] 보낼 카드 미리보기 ───────────────────" -ForegroundColor Cyan
  Write-Host "  제목 : $($template.content.title)"
  Write-Host "  설명 :"; ($desc -split "`n") | ForEach-Object { Write-Host "         $_" }
  Write-Host "  항목 :"; $cardItems | ForEach-Object { Write-Host "         - $($_.item) : $($_.item_op)" }
  Write-Host "  버튼 : 📊 대시보드 전체 보기 → $fullUrl"
  Write-Host "  (실제 발송은 -DryRun 없이 실행 / 가족·지인에겐 받은 카드를 '전달'하거나 위 링크를 붙여넣기)" -ForegroundColor DarkGray
  Write-Host ""
  exit 0
}

# ── 토큰 갱신 + 발송(나에게 보내기) ─────────────────────────────────────────
$tokPath = Join-Path $ScriptDir 'kakao_token.json'
if (-not (Test-Path $tokPath)) { Write-Host "  ⚠ 먼저 '카카오 연결.bat' 으로 연결하세요." -ForegroundColor Yellow; exit 1 }
$tok = Get-Content -Raw -Encoding UTF8 $tokPath | ConvertFrom-Json
$rest = "$($cfg.kakao.restApiKey)"
$rbody = @{ grant_type='refresh_token'; client_id=$rest; refresh_token="$($tok.refresh_token)" }
$sec = "$($cfg.kakao.clientSecret)"
if (-not [string]::IsNullOrWhiteSpace($sec) -and $sec -notlike '*<*') { $rbody['client_secret']=$sec }
try { $ref = Invoke-RestMethod -Uri 'https://kauth.kakao.com/oauth/token' -Method Post -Body $rbody }
catch { Write-Host "  ✖ 토큰 갱신 실패: $($_.Exception.Message). '카카오 연결.bat' 으로 재연결하세요." -ForegroundColor Red; exit 1 }
$access = "$($ref.access_token)"
$tok.access_token = $access
if ($ref.refresh_token) { $tok | Add-Member refresh_token "$($ref.refresh_token)" -Force }
$tok | Add-Member updated (Get-Date -Format 'yyyy-MM-dd HH:mm') -Force
$tok | ConvertTo-Json | Set-Content -Encoding UTF8 $tokPath

try {
  $res = Invoke-RestMethod -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' -Method Post `
    -Headers @{ Authorization = "Bearer $access" } -Body @{ template_object = $templateJson }
  if ("$($res.result_code)" -eq '0') { Write-Host "  ✓ 카카오톡(나에게) 주간 요약 발송 완료 — 가족·지인에게 '전달'하세요." -ForegroundColor Green }
  else { Write-Host "  ? 응답: $($res | ConvertTo-Json -Compress)" -ForegroundColor Yellow }
} catch {
  Write-Host "  ✖ 발송 실패: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "    카카오 앱의 talk_message 동의항목/토큰 유효성을 확인하세요." -ForegroundColor Yellow
  exit 1
}
