# ============================================================================
#  fetch.ps1  —  국토교통부 아파트 매매 실거래가 수집기
#  · config.json 의 지역/조건을 읽어 data.go.kr 실거래가 API 호출
#  · 전용면적 필터 적용 후 data/latest.js 생성 (대시보드가 읽음)
#  · 직전 실행과 비교해 '신규 거래' 자동 표시(NEW) + (선택) 알림
#  사용: 시세업데이트.bat 더블클릭  /  또는  powershell -File fetch.ps1
# ============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'config.json'
$DataDir    = Join-Path $ScriptDir 'data'
$LatestPath = Join-Path $DataDir   'latest.js'
$SeenPath   = Join-Path $DataDir   'seen.json'
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }

Write-Host ""
Write-Host "  ┌───────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │   분당·평촌·과천  실거래가 업데이트          │" -ForegroundColor Cyan
Write-Host "  └───────────────────────────────────────────┘" -ForegroundColor Cyan

if (-not (Test-Path $ConfigPath)) { Write-Host "  config.json 을 찾을 수 없습니다." -ForegroundColor Red; exit 1 }
$cfg = Get-Content -Raw -Encoding UTF8 $ConfigPath | ConvertFrom-Json

# ── 인증키 확인 ────────────────────────────────────────────────────────────
$rawKey = "$($cfg.serviceKey)".Trim()
if ([string]::IsNullOrWhiteSpace($rawKey) -or $rawKey -like '*붙여넣기*' -or $rawKey -like '*인증키*') {
  Write-Host ""
  Write-Host "  ⚠  아직 공공데이터포털 인증키가 등록되지 않았습니다." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  [발급 방법]  (무료, 약 1~2시간 내 승인)" -ForegroundColor White
  Write-Host "   1) https://www.data.go.kr  로그인 후"
  Write-Host "   2) '아파트 매매 실거래가 상세 자료' 검색 → 활용신청"
  Write-Host "   3) 마이페이지 > 오픈API > 인증키에서 '일반 인증키(Decoding)' 복사"
  Write-Host "   4) config.json 의 serviceKey 칸에 붙여넣고 저장 후 다시 실행"
  Write-Host ""
  Write-Host "  (지금은 인증키 없이도 대시보드를 예시 데이터로 열어볼 수 있습니다.)" -ForegroundColor DarkGray
  exit 0
}
$keyEnc = [uri]::EscapeDataString($rawKey)

# ── 조회 대상 월(YYYYMM) 목록 ──────────────────────────────────────────────
$monthsBack = [int]$cfg.monthsBack; if ($monthsBack -lt 1) { $monthsBack = 6 }
$months = @(); for ($i = 0; $i -lt $monthsBack; $i++) { $months += (Get-Date).AddMonths(-$i).ToString('yyyyMM') }

$areaMin = [double]$cfg.filter.areaMinM2
$areaMax = [double]$cfg.filter.areaMaxM2

# ── API 호출(페이징 + 401/일시오류 백오프 재시도 + 스로틀 회피 지연) ─────────
$Base = 'http://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev'
$RowsPer = 1000                       # 한 번에 많이 받아 호출 수↓(스로틀 회피). API가 100으로 잘라도 페이징으로 처리
$script:okHits = 0                    # 정상 응답 수
$script:reqFail = 0                   # 재시도 후에도 실패한 요청 수(일시 401/타임아웃)
$script:authHits = 0                  # 명시적 인증 오류(키 미등록 등)
$script:lastErr = ''; $script:lastAuthMsg = ''

# data.go.kr 은 빠른 연속 호출에 401 을 자주 반환 → 백오프 재시도 후에야 실패 처리
function Invoke-Api([string]$uri) {
  for ($try = 1; $try -le 5; $try++) {
    try { return Invoke-RestMethod -Uri $uri -TimeoutSec 60 }
    catch { $script:lastErr = "$($_.Exception.Message)"; if ($try -lt 5) { Start-Sleep -Milliseconds (400 * $try) } }
  }
  return $null
}

function Get-Trades([string]$code, [string]$ym) {
  $page = 1; $rows = @(); $total = -1
  do {
    $uri = "${Base}?serviceKey=$keyEnc&LAWD_CD=$code&DEAL_YMD=$ym&numOfRows=$RowsPer&pageNo=$page"
    $r = Invoke-Api $uri
    if ($null -eq $r) { $script:reqFail++; break }            # 재시도 후에도 실패 → 이 달 건너뜀
    if ($r.OpenAPI_ServiceResponse) {                          # 명시적 인증/등록 오류
      $h = $r.OpenAPI_ServiceResponse.cmmMsgHeader
      $script:authHits++; $script:lastAuthMsg = "$($h.returnReasonCode) / $($h.returnAuthMsg)"; break
    }
    $rc = "$($r.response.header.resultCode)"
    if ($rc -ne '000' -and $rc -ne '00') { $script:lastErr = "응답코드 $rc"; break }
    $script:okHits++
    if ($total -lt 0) { $total = [int]"$($r.response.body.totalCount)" }
    $items = @($r.response.body.items.item) | Where-Object { $_ }
    if ($items) { $rows += $items }
    $page++
    Start-Sleep -Milliseconds 200                              # 스로틀 회피용 호출 간 간격
  } while ( $total -gt 0 -and (($page - 1) * $RowsPer) -lt $total )
  return ,$rows
}

function To-Record($it, [string]$regionLabel, [string]$code) {
  if ("$($it.cdealType)".Trim() -eq 'O') { return $null }   # 해제(취소)된 거래 제외
  $amt  = 0; [void][int]::TryParse( ("$($it.dealAmount)" -replace '[^\d]',''), [ref]$amt )
  $area = 0.0; [void][double]::TryParse("$($it.excluUseAr)", [ref]$area)
  if ($amt -le 0 -or $area -le 0) { return $null }
  $y = [int]"$($it.dealYear)"; $m = [int]"$($it.dealMonth)"; $d = [int]"$($it.dealDay)"
  $fl = 0; [void][int]::TryParse("$($it.floor)", [ref]$fl)
  $by = 0; [void][int]::TryParse("$($it.buildYear)", [ref]$by)
  [pscustomobject][ordered]@{
    region       = $regionLabel
    code         = $code
    apt          = ("$($it.aptNm)").Trim()
    umd          = ("$($it.umdNm)").Trim()
    areaM2       = [math]::Round($area, 2)
    floor        = $fl
    amountManwon = $amt
    buildYear    = $by
    dealDate     = ('{0:0000}-{1:00}-{2:00}' -f $y, $m, $d)
    dealType     = ("$($it.dealingGbn)").Trim()
  }
}

function Median-Manwon($list) {
  $a = @($list | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ }) | Sort-Object
  if ($a.Count -eq 0) { return 0 }
  $m = [int][math]::Floor($a.Count / 2)
  if ($a.Count % 2) { return $a[$m] } else { return ($a[$m - 1] + $a[$m]) / 2 }
}

# ── 타겟 지역 수집 ─────────────────────────────────────────────────────────
$items = New-Object System.Collections.Generic.List[object]
foreach ($reg in $cfg.regions) {
  Write-Host ("  · {0} ({1}) 조회중..." -f $reg.label, $reg.code) -ForegroundColor Gray -NoNewline
  $cnt = 0
  foreach ($ym in $months) {
    foreach ($it in (Get-Trades $reg.code $ym)) {
      $rec = To-Record $it $reg.label $reg.code
      if ($null -ne $rec -and $rec.areaM2 -ge $areaMin -and $rec.areaM2 -le $areaMax) { $items.Add($rec); $cnt++ }
    }
  }
  Write-Host ("  {0}건" -f $cnt) -ForegroundColor Green
}

# ── 수집 결과 진단 ─────────────────────────────────────────────────────────
if ($script:okHits -eq 0) {
  Write-Host ""
  if ($script:authHits -gt 0) {
    Write-Host "  ✖ 인증 오류: $script:lastAuthMsg" -ForegroundColor Red
    Write-Host "    config.json 의 serviceKey 가 '일반 인증키(Decoding)' 인지, data.go.kr 활용신청이 '승인'됐는지 확인하세요." -ForegroundColor Red
  } else {
    Write-Host "  ✖ 모든 요청이 일시 오류로 실패했습니다 (마지막 오류: $script:lastErr)" -ForegroundColor Red
    Write-Host "    data.go.kr 일시 혼잡 또는 갓 발급한 키의 활성화 지연(최대 1~2시간)일 수 있습니다." -ForegroundColor Yellow
    Write-Host "    1~2분 뒤 다시 실행해 보세요. (키가 정상이어도 발생할 수 있는 일시 현상입니다.)" -ForegroundColor Yellow
  }
  exit 1
}
if ($script:reqFail -gt 0) {
  Write-Host ("  ⚠ 일부 요청이 일시 오류로 건너뛰어졌습니다({0}건). 잠시 후 다시 실행하면 누락분이 보완됩니다." -f $script:reqFail) -ForegroundColor Yellow
}

# ── 내 집(매도 예정) 수집 ──────────────────────────────────────────────────
$myItems = New-Object System.Collections.Generic.List[object]
if ($cfg.myHome -and $cfg.myHome.code) {
  $kw = "$($cfg.myHome.aptKeyword)"
  Write-Host ("  · 내 집 ({0}) 조회중..." -f $cfg.myHome.label) -ForegroundColor Gray -NoNewline
  foreach ($ym in $months) {
    foreach ($it in (Get-Trades $cfg.myHome.code $ym)) {
      $rec = To-Record $it $cfg.myHome.label $cfg.myHome.code
      if ($null -ne $rec -and $rec.apt -like "*$kw*") { $myItems.Add($rec) }
    }
  }
  Write-Host ("  {0}건" -f $myItems.Count) -ForegroundColor Green
}

# ── 신규 거래(NEW) 탐지 : 직전 실행 스냅샷과 비교 ──────────────────────────
$prevSeen = @{}; $firstRun = -not (Test-Path $SeenPath)
if (-not $firstRun) {
  try { (Get-Content -Raw -Encoding UTF8 $SeenPath | ConvertFrom-Json) | ForEach-Object { if ($_) { $prevSeen["$_"] = $true } } } catch {}
}
$curKeys = New-Object System.Collections.Generic.List[string]
$newCount = 0
foreach ($r in $items) {
  $k = '{0}|{1}|{2}|{3}|{4}|{5}' -f $r.region, $r.apt, $r.areaM2, $r.floor, $r.dealDate, $r.amountManwon
  $curKeys.Add($k)
  $isNew = (-not $firstRun) -and (-not $prevSeen.ContainsKey($k))
  $r | Add-Member -NotePropertyName isNew -NotePropertyValue $isNew -Force
  if ($isNew) { $newCount++ }
}
$keysJson = if ($curKeys.Count -gt 0) { $curKeys.ToArray() | ConvertTo-Json } else { '[]' }
[System.IO.File]::WriteAllText($SeenPath, $keysJson, (New-Object System.Text.UTF8Encoding($false)))

# ── 전세가율(전월세 실거래) 수집 : best-effort(미신청 시 건너뜀) ────────────
$RentBase = 'http://apis.data.go.kr/1613000/RTMSDataSvcAptRent/getRTMSDataSvcAptRent'
$doRent = $true
if ($cfg.PSObject.Properties.Name -contains 'fetchRent') { $doRent = [bool]$cfg.fetchRent }
$jeonse = [ordered]@{}
if ($doRent) {
  $probe = $null
  try { $probe = Invoke-RestMethod -Uri "${RentBase}?serviceKey=$keyEnc&LAWD_CD=$($cfg.regions[0].code)&DEAL_YMD=$($months[0])&numOfRows=1&pageNo=1" -TimeoutSec 30 } catch {}
  $rentOk = ($probe -and -not $probe.OpenAPI_ServiceResponse -and (@('000', '00') -contains "$($probe.response.header.resultCode)"))
  if (-not $rentOk) {
    Write-Host "  · 전세가율: 전월세 API 미활성 → 건너뜀 ('아파트 전월세 실거래가 자료' 활용신청 시 자동 표시)" -ForegroundColor DarkYellow
  } else {
    Write-Host "  · 전세가율(전월세) 조회중..." -ForegroundColor Gray -NoNewline
    foreach ($reg in $cfg.regions) {
      $deps = New-Object System.Collections.Generic.List[double]
      foreach ($ym in $months) {
        $page = 1; $total = -1
        do {
          $r = Invoke-Api "${RentBase}?serviceKey=$keyEnc&LAWD_CD=$($reg.code)&DEAL_YMD=$ym&numOfRows=$RowsPer&pageNo=$page"
          if ($null -eq $r -or $r.OpenAPI_ServiceResponse) { break }
          if (-not (@('000', '00') -contains "$($r.response.header.resultCode)")) { break }
          if ($total -lt 0) { $total = [int]"$($r.response.body.totalCount)" }
          foreach ($it in (@($r.response.body.items.item) | Where-Object { $_ })) {
            $mr = 0; [void][int]::TryParse((("$($it.monthlyRent)") -replace '[^\d]', ''), [ref]$mr)
            if ($mr -ne 0) { continue }                       # 전세만(월세 제외)
            $area = 0.0; [void][double]::TryParse("$($it.excluUseAr)", [ref]$area)
            if ($area -lt $areaMin -or $area -gt $areaMax) { continue }
            $dep = 0; [void][int]::TryParse((("$($it.deposit)") -replace '[^\d]', ''), [ref]$dep)
            if ($dep -gt 0) { $deps.Add([double]$dep) }
          }
          $page++; Start-Sleep -Milliseconds 150
        } while ($total -gt 0 -and (($page - 1) * $RowsPer) -lt $total)
      }
      $g = @($items | Where-Object { $_.region -eq $reg.label })
      $saleMed = Median-Manwon ($g | ForEach-Object { $_.amountManwon })
      if ($deps.Count -gt 0 -and $saleMed -gt 0) {
        $jMed = Median-Manwon $deps
        $jeonse[$reg.label] = [ordered]@{ ratioPct = [math]::Round($jMed / $saleMed * 100, 1); jeonseManwon = [int]$jMed; saleManwon = [int]$saleMed; count = $deps.Count }
      }
    }
    Write-Host ("  {0}개 지역" -f $jeonse.Keys.Count) -ForegroundColor Green
  }
}

# ── latest.js 작성 ─────────────────────────────────────────────────────────
$out = [ordered]@{
  isSample  = $false
  updatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  config    = @{ priceMaxEok = $cfg.filter.priceMaxEok; areaMin = $areaMin; areaMax = $areaMax }
  myHome    = @{ label = "$($cfg.myHome.label)"; addr = "$($cfg.myHome.addr)"; items = $myItems.ToArray() }
  items     = $items.ToArray()
  jeonse    = $jeonse
  watch     = @($cfg.watch)
  newCount  = $newCount
}
$json = $out | ConvertTo-Json -Depth 8
$content = "/* 자동 생성 파일 — 직접 수정하지 마세요. '① 시세 업데이트.bat' 실행 시 갱신됩니다. */`r`nwindow.REALTY_DATA = $json;`r`n"
[System.IO.File]::WriteAllText($LatestPath, $content, (New-Object System.Text.UTF8Encoding($false)))
# 카톡 발송 등 프로그램용 순수 JSON 도 함께 출력
[System.IO.File]::WriteAllText((Join-Path $DataDir 'latest.json'), $json, (New-Object System.Text.UTF8Encoding($false)))

# ── 신규 알림(선택: BurntToast 모듈이 있으면 토스트 표시) ──────────────────
if ($newCount -gt 0) {
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction Stop
      New-BurntToastNotification -Text "새 실거래 ${newCount}건 등록", "분당·평촌·과천 30평대 신규 거래가 있습니다. 대시보드에서 확인하세요." | Out-Null
    }
  } catch {}
}

# ── 요약 출력 ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ─── 업데이트 완료 ───────────────────────────" -ForegroundColor Cyan
foreach ($reg in $cfg.regions) {
  $g = @($items | Where-Object { $_.region -eq $reg.label })
  $under = @($g | Where-Object { $_.amountManwon -le ([int]$cfg.filter.priceMaxEok * 10000) }).Count
  Write-Host ("   {0,-4} : 총 {1,3}건 · 예산({2}억) 이내 {3,3}건" -f $reg.label, $g.Count, $cfg.filter.priceMaxEok, $under)
}
if ($myItems.Count -gt 0) {
  $avg = [math]::Round(($myItems | Measure-Object amountManwon -Average).Average / 10000, 2)
  Write-Host ("   내집 : 최근 {0}건 · 평균 매도가 약 {1}억" -f $myItems.Count, $avg) -ForegroundColor White
}
Write-Host ("   신규(NEW) : {0}건" -f $newCount) -ForegroundColor $(if ($newCount -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host ""
Write-Host "   → '대시보드.bat' 으로 결과를 확인하세요." -ForegroundColor Green
Write-Host ""
