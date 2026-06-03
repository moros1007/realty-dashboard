# ============================================================================
#  cheonho_fetch.ps1  —  천호교회(천호역 8호선) 접근 · 역세권 매물 수집기
#  ──────────────────────────────────────────────────────────────────────────
#  · config.json 의 cheonho.regions(송파·강동·성남·구리·다산/별내)를 읽어
#    국토부 '아파트 매매' + '아파트 전월세' 실거래가 API 호출
#  · 단지별 전세 실거래 중앙값으로 '갭(매매−전세)' 추정 → 5억 자본 매칭
#  · 전용면적 필터 후 data/cheonho.js 생성 (cheonho.html 이 읽음)
#  · 직전 실행 대비 신규 거래(NEW) 표시
#  사용: '⑤ 천호 역세권 업데이트.bat' 더블클릭  /  powershell -File cheonho_fetch.ps1
# ============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'config.json'
$DataDir    = Join-Path $ScriptDir 'data'
$OutPath    = Join-Path $DataDir   'cheonho.js'
$SeenPath   = Join-Path $DataDir   'cheonho_seen.json'
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }

Write-Host ""
Write-Host "  +-----------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  천호역(8호선) 접근 · 역세권 매물 업데이트     |" -ForegroundColor Cyan
Write-Host "  |  송파 / 강동 / 성남 + (별내선) 구리·다산·별내  |" -ForegroundColor Cyan
Write-Host "  +-----------------------------------------------+" -ForegroundColor Cyan

if (-not (Test-Path $ConfigPath)) { Write-Host "  config.json 을 찾을 수 없습니다." -ForegroundColor Red; exit 1 }
$cfg = Get-Content -Raw -Encoding UTF8 $ConfigPath | ConvertFrom-Json

# ── 인증키 확인 ──────────────────────────────────────────────────────────────
$rawKey = "$($cfg.serviceKey)".Trim()
if ([string]::IsNullOrWhiteSpace($rawKey) -or $rawKey -like '*붙여넣기*' -or $rawKey -like '*인증키*') {
  Write-Host ""
  Write-Host "  ⚠  공공데이터포털 인증키(serviceKey)가 아직 등록되지 않았습니다." -ForegroundColor Yellow
  Write-Host "     config.json 의 serviceKey 를 채우거나, 인증키 없이도 cheonho.html 을 예시로 열어볼 수 있습니다." -ForegroundColor DarkGray
  exit 0
}
$keyEnc = [uri]::EscapeDataString($rawKey)

# ── 설정 ────────────────────────────────────────────────────────────────────
$ch = $cfg.cheonho
if ($null -eq $ch) { Write-Host "  config.json 에 'cheonho' 설정이 없습니다." -ForegroundColor Red; exit 1 }
$regions    = @($ch.regions)
$monthsBack = [int]$ch.monthsBack; if ($monthsBack -lt 1) { $monthsBack = 4 }
$areaMin    = [double]$ch.areaMinM2; if ($areaMin -le 0) { $areaMin = 45 }
$areaMax    = [double]$ch.areaMaxM2; if ($areaMax -le 0) { $areaMax = 90 }
$capEok     = [double]$ch.capEok;    if ($capEok  -le 0) { $capEok  = 5 }

$months = @(); for ($i = 0; $i -lt $monthsBack; $i++) { $months += (Get-Date).AddMonths(-$i).ToString('yyyyMM') }

# ── API 공통 ─────────────────────────────────────────────────────────────────
$SaleBase = 'http://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev'
$RentBase = 'http://apis.data.go.kr/1613000/RTMSDataSvcAptRent/getRTMSDataSvcAptRent'
$RowsPer  = 1000
$script:okHits = 0; $script:reqFail = 0; $script:authHits = 0; $script:lastErr = ''; $script:lastAuthMsg = ''

function Invoke-Api([string]$uri) {
  for ($try = 1; $try -le 5; $try++) {
    try { return Invoke-RestMethod -Uri $uri -TimeoutSec 60 }
    catch { $script:lastErr = "$($_.Exception.Message)"; if ($try -lt 5) { Start-Sleep -Milliseconds (400 * $try) } }
  }
  return $null
}

function Get-Page([string]$base, [string]$code, [string]$ym) {
  $page = 1; $rows = @(); $total = -1
  do {
    $uri = "${base}?serviceKey=$keyEnc&LAWD_CD=$code&DEAL_YMD=$ym&numOfRows=$RowsPer&pageNo=$page"
    $r = Invoke-Api $uri
    if ($null -eq $r) { $script:reqFail++; break }
    if ($r.OpenAPI_ServiceResponse) {
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
    Start-Sleep -Milliseconds 180
  } while ( $total -gt 0 -and (($page - 1) * $RowsPer) -lt $total )
  return ,$rows
}

# 단지명 정규화(매매↔전세 매칭용): 공백 제거
function Norm([string]$s) { return (("$s") -replace '\s', '').Trim() }

function Median($list) {
  $a = @($list | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ }) | Sort-Object
  if ($a.Count -eq 0) { return 0 }
  $m = [int][math]::Floor($a.Count / 2)
  if ($a.Count % 2) { return $a[$m] } else { return ($a[$m - 1] + $a[$m]) / 2 }
}

# ── 1) 매매 실거래 수집 ──────────────────────────────────────────────────────
$sales = New-Object System.Collections.Generic.List[object]
foreach ($reg in $regions) {
  $allow = @($reg.umdAllow)               # 비어있으면 전체 허용
  Write-Host ("  · [{0}] {1} 매매 조회중..." -f $reg.group, $reg.label) -ForegroundColor Gray -NoNewline
  $cnt = 0
  foreach ($ym in $months) {
    foreach ($it in (Get-Page $SaleBase $reg.code $ym)) {
      if ("$($it.cdealType)".Trim() -eq 'O') { continue }            # 해제 거래 제외
      $umd = ("$($it.umdNm)").Trim()
      if ($allow.Count -gt 0 -and ($allow -notcontains $umd)) { continue }
      $amt = 0; [void][int]::TryParse( ("$($it.dealAmount)" -replace '[^\d]',''), [ref]$amt )
      $area = 0.0; [void][double]::TryParse("$($it.excluUseAr)", [ref]$area)
      if ($amt -le 0 -or $area -lt $areaMin -or $area -gt $areaMax) { continue }
      $y = [int]"$($it.dealYear)"; $m = [int]"$($it.dealMonth)"; $d = [int]"$($it.dealDay)"
      $fl = 0; [void][int]::TryParse("$($it.floor)", [ref]$fl)
      $by = 0; [void][int]::TryParse("$($it.buildYear)", [ref]$by)
      $sales.Add([pscustomobject][ordered]@{
        group        = "$($reg.group)"
        region       = "$($reg.label)"
        code         = "$($reg.code)"
        apt          = ("$($it.aptNm)").Trim()
        umd          = $umd
        areaM2       = [math]::Round($area, 2)
        floor        = $fl
        amountManwon = $amt
        buildYear    = $by
        dealDate     = ('{0:0000}-{1:00}-{2:00}' -f $y, $m, $d)
        dealType     = ("$($it.dealingGbn)").Trim()
      })
      $cnt++
    }
  }
  Write-Host ("  {0}건" -f $cnt) -ForegroundColor Green
}

if ($script:okHits -eq 0) {
  Write-Host ""
  if ($script:authHits -gt 0) {
    Write-Host "  ✖ 인증 오류: $script:lastAuthMsg" -ForegroundColor Red
    Write-Host "    serviceKey 가 '일반 인증키(Decoding)' 인지, data.go.kr 활용신청이 '승인'됐는지 확인하세요." -ForegroundColor Red
  } else {
    Write-Host "  ✖ 모든 요청이 일시 오류로 실패 (마지막 오류: $script:lastErr). 1~2분 뒤 다시 실행해 보세요." -ForegroundColor Red
  }
  exit 1
}

# ── 2) 전세 실거래 수집 → 단지별 / 지역별 전세 중앙값 ─────────────────────────
#     갭(매매−전세) 추정의 핵심. 전월세 API 미활성 시 지역 전세가율로 폴백.
$jByApt    = @{}    # 정규화단지명  -> [전세보증금(만원) 목록]
$jByRegion = @{}    # region        -> [전세보증금(만원) 목록]
$rentProbe = $null
try { $rentProbe = Invoke-RestMethod -Uri "${RentBase}?serviceKey=$keyEnc&LAWD_CD=$($regions[0].code)&DEAL_YMD=$($months[0])&numOfRows=1&pageNo=1" -TimeoutSec 30 } catch {}
$rentOk = ($rentProbe -and -not $rentProbe.OpenAPI_ServiceResponse -and (@('000','00') -contains "$($rentProbe.response.header.resultCode)"))

if (-not $rentOk) {
  Write-Host "  · 전세: 전월세 API 미활성 → 지역 전세가율(추정)로 갭 계산" -ForegroundColor DarkYellow
} else {
  foreach ($reg in $regions) {
    $allow = @($reg.umdAllow)
    Write-Host ("  · [{0}] {1} 전세 조회중..." -f $reg.group, $reg.label) -ForegroundColor Gray -NoNewline
    $cnt = 0
    foreach ($ym in $months) {
      foreach ($it in (Get-Page $RentBase $reg.code $ym)) {
        $mr = 0; [void][int]::TryParse((("$($it.monthlyRent)") -replace '[^\d]',''), [ref]$mr)
        if ($mr -ne 0) { continue }                                   # 전세만(월세 제외)
        $umd = ("$($it.umdNm)").Trim()
        if ($allow.Count -gt 0 -and ($allow -notcontains $umd)) { continue }
        $area = 0.0; [void][double]::TryParse("$($it.excluUseAr)", [ref]$area)
        if ($area -lt $areaMin -or $area -gt $areaMax) { continue }
        $dep = 0; [void][int]::TryParse((("$($it.deposit)") -replace '[^\d]',''), [ref]$dep)
        if ($dep -le 0) { continue }
        $key = (Norm "$($it.aptNm)") + '|' + [int][math]::Round($area / 10.0)   # 단지+면적대(10㎡ 버킷)
        if (-not $jByApt.ContainsKey($key))            { $jByApt[$key] = New-Object System.Collections.Generic.List[double] }
        $jByApt[$key].Add([double]$dep)
        if (-not $jByRegion.ContainsKey($reg.label))   { $jByRegion[$reg.label] = New-Object System.Collections.Generic.List[double] }
        $jByRegion[$reg.label].Add([double]$dep)
        $cnt++
      }
    }
    Write-Host ("  {0}건" -f $cnt) -ForegroundColor Green
  }
}

# 지역 전세가율(매매 중앙값 대비) — 폴백/표시용
$regionJeonse = [ordered]@{}
foreach ($reg in $regions) {
  $g = @($sales | Where-Object { $_.region -eq $reg.label })
  $saleMed = Median ($g | ForEach-Object { $_.amountManwon })
  $jMed = if ($jByRegion.ContainsKey($reg.label)) { Median $jByRegion[$reg.label] } else { 0 }
  if ($saleMed -gt 0) {
    $regionJeonse[$reg.label] = [ordered]@{
      ratioPct     = if ($jMed -gt 0) { [math]::Round($jMed / $saleMed * 100, 1) } else { $null }
      jeonseManwon = [int]$jMed
      saleManwon   = [int]$saleMed
    }
  }
}
# 전세 데이터가 아예 없을 때 쓰는 지역군 기본 전세가율(보수적 추정)
$fallbackRatio = @{ '송파'=0.52; '강동'=0.55; '성남'=0.60; '별내선'=0.58; '분당'=0.55 }

# ── 3) 각 매매건에 전세추정 + 갭 부여 ────────────────────────────────────────
foreach ($s in $sales) {
  $key = (Norm $s.apt) + '|' + [int][math]::Round($s.areaM2 / 10.0)
  $jEst = 0; $src = 'none'
  if ($jByApt.ContainsKey($key) -and $jByApt[$key].Count -ge 1) {
    $jEst = [int](Median $jByApt[$key]); $src = 'complex'
  } elseif ($regionJeonse.Contains($s.region) -and $regionJeonse[$s.region].ratioPct) {
    $jEst = [int]([math]::Round($s.amountManwon * ($regionJeonse[$s.region].ratioPct / 100.0))); $src = 'region'
  } else {
    $rr = $fallbackRatio[$s.group]; if (-not $rr) { $rr = 0.55 }
    $jEst = [int]([math]::Round($s.amountManwon * $rr)); $src = 'assume'
  }
  $gap = $s.amountManwon - $jEst
  $s | Add-Member -NotePropertyName jeonseManwon -NotePropertyValue $jEst -Force
  $s | Add-Member -NotePropertyName jeonseSrc    -NotePropertyValue $src  -Force
  $s | Add-Member -NotePropertyName gapManwon    -NotePropertyValue $gap  -Force
}

# ── 4) 신규(NEW) 탐지 ────────────────────────────────────────────────────────
$prevSeen = @{}; $firstRun = -not (Test-Path $SeenPath)
if (-not $firstRun) {
  try { (Get-Content -Raw -Encoding UTF8 $SeenPath | ConvertFrom-Json) | ForEach-Object { if ($_) { $prevSeen["$_"] = $true } } } catch {}
}
$curKeys = New-Object System.Collections.Generic.List[string]
$newCount = 0
foreach ($s in $sales) {
  $k = '{0}|{1}|{2}|{3}|{4}|{5}' -f $s.region, $s.apt, $s.areaM2, $s.floor, $s.dealDate, $s.amountManwon
  $curKeys.Add($k)
  $isNew = (-not $firstRun) -and (-not $prevSeen.ContainsKey($k))
  $s | Add-Member -NotePropertyName isNew -NotePropertyValue $isNew -Force
  if ($isNew) { $newCount++ }
}
$keysJson = if ($curKeys.Count -gt 0) { $curKeys.ToArray() | ConvertTo-Json } else { '[]' }
[System.IO.File]::WriteAllText($SeenPath, $keysJson, (New-Object System.Text.UTF8Encoding($false)))

# ── 5) cheonho.js 작성 ───────────────────────────────────────────────────────
$out = [ordered]@{
  isSample      = $false
  updatedAt     = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  anchor        = "천호역(5·8호선)"
  config        = @{ capEok = $capEok; areaMin = $areaMin; areaMax = $areaMax; monthsBack = $monthsBack }
  items         = $sales.ToArray()
  regionJeonse  = $regionJeonse
  newCount      = $newCount
}
$json = $out | ConvertTo-Json -Depth 8
$content = "/* 자동 생성 — 직접 수정 금지. 'ⓢ 천호 역세권 업데이트.bat' 실행 시 갱신됩니다. */`r`nwindow.CHEONHO_DATA = $json;`r`n"
[System.IO.File]::WriteAllText($OutPath, $content, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText((Join-Path $DataDir 'cheonho.json'), $json, (New-Object System.Text.UTF8Encoding($false)))

# ── 요약 ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  --- 업데이트 완료 -----------------------------" -ForegroundColor Cyan
$capManwon = [int]($capEok * 10000)
foreach ($reg in $regions) {
  $g = @($sales | Where-Object { $_.region -eq $reg.label })
  $priceOk = @($g | Where-Object { $_.amountManwon -le ($capManwon+5000) }).Count
  Write-Host ("   {0,-8} 총 {1,4}건 · 매매 {2}억선 {3,4}건" -f $reg.label, $g.Count, $capEok, $priceOk)
}
Write-Host ("   신규(NEW): {0}건" -f $newCount) -ForegroundColor $(if ($newCount -gt 0) { 'Yellow' } else { 'Gray' })
if ($script:reqFail -gt 0) { Write-Host ("   ⚠ 일시오류로 건너뛴 요청 {0}건 — 다시 실행하면 보완됩니다." -f $script:reqFail) -ForegroundColor Yellow }
Write-Host ""
Write-Host "   → '⑥ 천호 대시보드 열기.bat' 으로 확인하세요." -ForegroundColor Green
Write-Host ""
