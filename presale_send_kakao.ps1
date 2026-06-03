# ============================================================================
#  presale_send_kakao.ps1 — 카카오톡 '나에게 보내기'로 분양·미분양 요약 카드 발송
#   · 매매 send_kakao.ps1 과 동일 방식(feed 카드 + [대시보드 전체 보기] 버튼)
#   · config.kakao(restApiKey/clientSecret) + kakao_token.json(refresh_token) 공유
#   · data/presale.js 를 요약 / 버튼은 분양 대시보드(presale.html)로 연결
#   · -DryRun : 토큰·발송 없이 보낼 내용만 미리보기
# ============================================================================
param([switch]$DryRun)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = Get-Content -Raw -Encoding UTF8 (Join-Path $ScriptDir 'config.json') | ConvertFrom-Json

# 분양 대시보드 주소 (config.github 으로 자동 구성)
$gh = $cfg.github
$url = if ($gh -and "$($gh.owner)" -and "$($gh.repo)") { "https://$($gh.owner).github.io/$($gh.repo)/presale.html" } else { 'https://moros1007.github.io/realty-dashboard/presale.html' }

# data/presale.js 파싱
function EokS($man) { if ([math]::Abs([double]$man) -ge 10000) { ('{0}억' -f [math]::Round([double]$man / 10000, 1)) } else { ('{0:N0}만' -f [math]::Round([double]$man)) } }
$items = @()
$updatedAt = ''
$f = Join-Path (Join-Path $ScriptDir 'data') 'presale.js'
if (Test-Path $f) {
  try {
    $o = ((Get-Content $f -Raw -Encoding UTF8) -replace '(?s)^.*?window\.PRESALE_DATA\s*=\s*', '' -replace ';\s*$', '') | ConvertFrom-Json
    $items = @($o.items); $updatedAt = "$($o.updatedAt)"
  } catch {}
}
$total = $items.Count
$bun  = @($items | Where-Object { $_.kind -eq '분양권' }).Count
$soon = @($items | Where-Object { $_.kind -eq '무순위' -or $_.kind -eq '미분양' }).Count
$new  = @($items | Where-Object { $_.kind -eq '분양' }).Count
$cheap = @($items | Where-Object { $_.kind -eq '분양권' -and $_.priceManwon -gt 0 } | Sort-Object priceManwon | Select-Object -First 1)

$listItems = @(
  @{ item = '분양권 전매';   item_op = ('{0:N0}건' -f $bun) }
  @{ item = '무순위·미분양'; item_op = ('{0:N0}건 (즉시매수)' -f $soon) }
  @{ item = '신규분양';     item_op = ('{0:N0}건' -f $new) }
)
if ($cheap.Count) { $listItems += @{ item = '최저 분양권'; item_op = ("{0} {1}" -f $cheap[0].region, (EokS $cheap[0].priceManwon)) } }

$today = (Get-Date).ToString('M월 d일')
$desc = "거래가능 {0:N0}건 · 실거주의무/대출/월납부까지`n경기=시별 · 서울=구별 조회" -f $total

$template = @{
  object_type  = 'feed'
  content      = @{ title = "🏢 $today 수도권 분양·미분양"; description = $desc; link = @{ web_url = $url; mobile_web_url = $url } }
  item_content = @{ items = $listItems }
  buttons      = @( @{ title = '📊 대시보드 전체 보기'; link = @{ web_url = $url; mobile_web_url = $url } } )
}
$templateJson = $template | ConvertTo-Json -Depth 10 -Compress

if ($DryRun) {
  Write-Host ""
  Write-Host "  ── [DryRun] 분양 카드 미리보기 ───────────────────" -ForegroundColor Cyan
  Write-Host "  제목 : $($template.content.title)"
  ($desc -split "`n") | ForEach-Object { Write-Host "  설명 : $_" }
  $listItems | ForEach-Object { Write-Host ("  항목 : {0} — {1}" -f $_.item, $_.item_op) }
  Write-Host "  버튼 : 📊 대시보드 전체 보기 → $url"
  Write-Host ""
  exit 0
}

# ── 토큰 갱신 (send_kakao.ps1 과 동일) ─────────────────────────────────────────
$tokPath = Join-Path $ScriptDir 'kakao_token.json'
if (-not (Test-Path $tokPath)) { Write-Host "  ⚠ 먼저 '카카오 연결.bat' 으로 연결하세요." -ForegroundColor Yellow; exit 1 }
$tok = Get-Content -Raw -Encoding UTF8 $tokPath | ConvertFrom-Json
$rbody = @{ grant_type = 'refresh_token'; client_id = "$($cfg.kakao.restApiKey)"; refresh_token = "$($tok.refresh_token)" }
$sec = "$($cfg.kakao.clientSecret)"
if (-not [string]::IsNullOrWhiteSpace($sec) -and $sec -notlike '*<*') { $rbody['client_secret'] = $sec }
try { $ref = Invoke-RestMethod -Uri 'https://kauth.kakao.com/oauth/token' -Method Post -Body $rbody }
catch { Write-Host "  ✖ 토큰 갱신 실패: $($_.Exception.Message). '카카오 연결.bat' 으로 재연결하세요." -ForegroundColor Red; exit 1 }
$access = "$($ref.access_token)"
$tok.access_token = $access
if ($ref.refresh_token) { $tok | Add-Member refresh_token "$($ref.refresh_token)" -Force }
$tok | Add-Member updated (Get-Date -Format 'yyyy-MM-dd HH:mm') -Force
$tok | ConvertTo-Json | Set-Content -Encoding UTF8 $tokPath

# ── 발송 ───────────────────────────────────────────────────────────────────
try {
  $res = Invoke-RestMethod -Uri 'https://kapi.kakao.com/v2/api/talk/memo/default/send' -Method Post `
    -Headers @{ Authorization = "Bearer $access" } -Body @{ template_object = $templateJson }
  if ("$($res.result_code)" -eq '0') { Write-Host "  ✓ 분양 카카오톡 발송 완료 ($today, 거래가능 ${total}건)" -ForegroundColor Green }
  else { Write-Host "  ? 응답: $($res | ConvertTo-Json -Compress)" -ForegroundColor Yellow }
} catch {
  Write-Host "  ✖ 발송 실패: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "    카카오 talk_message 동의항목/토큰 유효성을 확인하세요." -ForegroundColor Yellow
  exit 1
}
