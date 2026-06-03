# ============================================================================
#  presale_fetch.ps1  —  수도권 미분양·분양권 수집기
#   1) 국토교통부 '아파트 분양권전매 실거래가'(데이터 15126471) → 거래가능 분양권
#   2) 한국부동산원 '청약홈 분양정보'(데이터 15098547) → 무순위/잔여세대 + 신규분양
#      · 공고(Detail) + 주택형별(Mdl, 분양가 LTTOT_TOP_AMOUNT) 결합 → 분양가/전용 확보
#   · config.json 의 serviceKey 공유, presale 설정 사용
#   · 결과를 data/presale.js (window.PRESALE_DATA) 로 생성
#  사용: 「③ 분양·미분양 업데이트.bat」  또는  powershell -File presale_fetch.ps1
# ============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'config.json'
$DataDir    = Join-Path $ScriptDir 'data'
$OutPath    = Join-Path $DataDir   'presale.js'
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir | Out-Null }

Write-Host ""
Write-Host "  ┌───────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │   수도권 미분양·분양권 업데이트                  │" -ForegroundColor Cyan
Write-Host "  └───────────────────────────────────────────────┘" -ForegroundColor Cyan

if (-not (Test-Path $ConfigPath)) { Write-Host "  config.json 을 찾을 수 없습니다." -ForegroundColor Red; exit 1 }
$cfg = Get-Content -Raw -Encoding UTF8 $ConfigPath | ConvertFrom-Json

$rawKey = "$($cfg.serviceKey)".Trim()
if ([string]::IsNullOrWhiteSpace($rawKey) -or $rawKey -like '*붙여넣기*' -or $rawKey -like '*인증키*') {
  Write-Host ""
  Write-Host "  ⚠  공공데이터포털 인증키가 없습니다. (예시 데이터로 대시보드는 열람 가능)" -ForegroundColor Yellow
  Write-Host "   1) https://www.data.go.kr 로그인"
  Write-Host "   2) '아파트 분양권전매 실거래가 자료' + '청약홈 분양정보 조회 서비스' 활용신청"
  Write-Host "   3) 마이페이지 > 오픈API > '일반 인증키(Decoding)' 복사"
  Write-Host "   4) config.json 의 serviceKey 에 붙여넣고 다시 실행"
  exit 0
}
$keyEnc = [uri]::EscapeDataString($rawKey)

# ── 설정 ─────────────────────────────────────────────────────────────────────
$presale = $cfg.presale
$monthsBack = if ($presale -and $presale.monthsBack) { [int]$presale.monthsBack } else { 6 }
if ($monthsBack -lt 1) { $monthsBack = 6 }
$months = @(); for ($i = 0; $i -lt $monthsBack; $i++) { $months += (Get-Date).AddMonths(-$i).ToString('yyyyMM') }

$defaultCodes = @(
  '41290','41210','41135','41131','41133','41117','41111','41115','41173','41465','41430','41450',
  '11680','11710','11440','11620','11500','11350',
  '41220','41550','41500','41630','41480','41570','41590','41360','41271','41461','41281',
  '28260','28185','28200','28237'
)
$codes = if ($presale -and $presale.regionCodes) { @($presale.regionCodes) } else { $defaultCodes }
$silvEndpoint = if ($presale -and $presale.silvEndpoint) { "$($presale.silvEndpoint)" } else {
  'http://apis.data.go.kr/1613000/RTMSDataSvcSilvTrade/getRTMSDataSvcSilvTrade' }
$applyBase = if ($presale -and $presale.applyhomeBase) { "$($presale.applyhomeBase)" } else {
  'https://api.odcloud.kr/api/ApplyhomeInfoDetailSvc/v1' }
$doApply = -not ($presale -and $presale.fetchApplyhome -eq $false)

$SGG = @{
  '11110'='서울 종로구';'11140'='서울 중구';'11170'='서울 용산구';'11200'='서울 성동구';'11215'='서울 광진구';
  '11230'='서울 동대문구';'11260'='서울 중랑구';'11290'='서울 성북구';'11305'='서울 강북구';'11320'='서울 도봉구';
  '11350'='서울 노원구';'11380'='서울 은평구';'11410'='서울 서대문구';'11440'='서울 마포구';'11470'='서울 양천구';
  '11500'='서울 강서구';'11530'='서울 구로구';'11545'='서울 금천구';'11560'='서울 영등포구';'11590'='서울 동작구';
  '11620'='서울 관악구';'11650'='서울 서초구';'11680'='서울 강남구';'11710'='서울 송파구';'11740'='서울 강동구';
  '41111'='수원 장안구';'41113'='수원 권선구';'41115'='수원 팔달구';'41117'='수원 영통구';'41131'='성남 수정구';
  '41133'='성남 중원구';'41135'='성남 분당구';'41150'='의정부시';'41171'='안양 만안구';'41173'='안양 동안구';
  '41190'='부천시';'41210'='광명시';'41220'='평택시';'41271'='안산 상록구';'41273'='안산 단원구';
  '41281'='고양 덕양구';'41285'='고양 일산동구';'41287'='고양 일산서구';'41290'='과천시';'41360'='남양주시';
  '41390'='시흥시';'41410'='군포시';'41430'='의왕시';'41450'='하남시';'41461'='용인 처인구';'41463'='용인 기흥구';'41465'='용인 수지구';
  '41480'='파주시';'41500'='이천시';'41550'='안성시';'41570'='김포시';'41590'='화성시';'41610'='광주시';'41630'='양주시';
  '28110'='인천 중구';'28140'='인천 동구';'28177'='인천 미추홀구';'28185'='인천 연수구';'28200'='인천 남동구';
  '28237'='인천 부평구';'28245'='인천 계양구';'28260'='인천 서구';'28710'='인천 강화군'
}
function RegName([string]$code) { if ($SGG.ContainsKey($code)) { $SGG[$code] } else { "지역($code)" } }

# ── 1) 분양권 전매 실거래 ──────────────────────────────────────────────────────
$items = New-Object System.Collections.Generic.List[object]
$script:authError = $false; $script:silvForbidden = $false; $script:silvWarned = $false

function Get-Silv([string]$code, [string]$ym) {
  $page = 1; $rows = @(); $total = -1
  do {
    $uri = "$silvEndpoint`?serviceKey=$keyEnc&LAWD_CD=$code&DEAL_YMD=$ym&numOfRows=100&pageNo=$page"
    try { $r = Invoke-RestMethod -Uri $uri -TimeoutSec 40 }
    catch {
      $sc = $null; if ($_.Exception.Response) { $sc = [int]$_.Exception.Response.StatusCode }
      if ($sc -eq 403) {
        if (-not $script:silvWarned) { Write-Host "      ! 분양권전매(데이터 15126471)가 이 인증키에 미승인(403)입니다. data.go.kr에서 활용신청 후 사용하세요. (분양권 건너뜀)" -ForegroundColor Red; $script:silvWarned = $true }
        $script:silvForbidden = $true
      } else { Write-Host "      ! $code/$ym 요청 실패: $($_.Exception.Message)" -ForegroundColor DarkYellow }
      break
    }
    if ($r.OpenAPI_ServiceResponse) {
      Write-Host ("      ! 인증/요청 오류: {0}" -f $r.OpenAPI_ServiceResponse.cmmMsgHeader.returnAuthMsg) -ForegroundColor Red
      $script:authError = $true; break
    }
    $rc = "$($r.response.header.resultCode)"
    if ($rc -ne '000' -and $rc -ne '00') { Write-Host "      ! 응답코드 $rc : $($r.response.header.resultMsg)" -ForegroundColor DarkYellow; break }
    if ($total -lt 0) { $total = [int]"$($r.response.body.totalCount)" }
    $it = @($r.response.body.items.item) | Where-Object { $_ }
    if ($it) { $rows += $it }
    $page++
  } while ( $total -gt 0 -and (($page - 1) * 100) -lt $total )
  return ,$rows
}
function To-SilvRecord($it, [string]$queryCode) {
  if ("$($it.cdealType)".Trim() -eq 'O') { return $null }
  $amt = 0; [void][int]::TryParse( ("$($it.dealAmount)" -replace '[^\d]',''), [ref]$amt )
  $area = 0.0; [void][double]::TryParse("$($it.excluUseAr)", [ref]$area)
  if ($amt -le 0 -or $area -le 0) { return $null }
  $code = "$($it.sggCd)".Trim(); if ([string]::IsNullOrWhiteSpace($code)) { $code = $queryCode }
  $code = $code.Substring(0, [Math]::Min(5, $code.Length))
  $y = [int]"$($it.dealYear)"; $m = [int]"$($it.dealMonth)"; $d = [int]"$($it.dealDay)"
  $fl = 0; [void][int]::TryParse("$($it.floor)", [ref]$fl)
  [pscustomobject][ordered]@{
    kind='분양권'; code=$code; region=(RegName $code); umd=("$($it.umdNm)").Trim(); apt=("$($it.aptNm)").Trim()
    areaM2=[math]::Round($area,2); floor=$fl; priceManwon=$amt
    dealDate=('{0:0000}-{1:00}-{2:00}' -f $y,$m,$d); contractYM=$null; moveInYM=$null
    supplyUnits=$null; pblancUrl=$null
  }
}

Write-Host ("  · 분양권 전매 실거래 수집 (수도권 {0}개 지역 × 최근 {1}개월)" -f $codes.Count, $monthsBack) -ForegroundColor Gray
foreach ($code in $codes) {
  $cnt = 0
  foreach ($ym in $months) {
    foreach ($it in (Get-Silv $code $ym)) { $rec = To-SilvRecord $it $code; if ($null -ne $rec) { $items.Add($rec); $cnt++ } }
    if ($script:authError -or $script:silvForbidden) { break }
  }
  Write-Host ("    {0,-12} {1,3}건" -f (RegName $code), $cnt) -ForegroundColor DarkGray
  if ($script:authError -or $script:silvForbidden) { break }
}

# ── 2) 청약홈 무순위/잔여세대 + 분양 (공고 Detail + 주택형 Mdl 결합) ──────────────
$NAME2CODE = [ordered]@{
  '일산동구'='41285';'일산서구'='41287';'분당구'='41135';'수정구'='41131';'중원구'='41133';
  '영통구'='41117';'장안구'='41111';'팔달구'='41115';'권선구'='41113';'만안구'='41171';'동안구'='41173';
  '처인구'='41461';'기흥구'='41463';'수지구'='41465';'덕양구'='41281';'상록구'='41271';'단원구'='41273';
  '종로구'='11110';'중구'='11140';'용산구'='11170';'성동구'='11200';'광진구'='11215';'동대문구'='11230';'중랑구'='11260';
  '성북구'='11290';'강북구'='11305';'도봉구'='11320';'노원구'='11350';'은평구'='11380';'서대문구'='11410';
  '마포구'='11440';'양천구'='11470';'강서구'='11500';'구로구'='11530';'금천구'='11545';'영등포구'='11560';
  '동작구'='11590';'관악구'='11620';'서초구'='11650';'강남구'='11680';'송파구'='11710';'강동구'='11740';
  '과천시'='41290';'광명시'='41210';'평택시'='41220';'남양주시'='41360';'시흥시'='41390';'군포시'='41410';'의왕시'='41430';
  '하남시'='41450';'파주시'='41480';'이천시'='41500';'안성시'='41550';'김포시'='41570';'화성시'='41590';
  '양주시'='41630';'광주시'='41610';'부천시'='41190';'의정부시'='41150';'안산시'='41273';'고양시'='41281';
  '미추홀구'='28177';'연수구'='28185';'남동구'='28200';'부평구'='28237';'계양구'='28245';'강화군'='28710'
}
function AddrToCode([string]$addr) {
  $addr = $addr -replace '특례시', '시'
  foreach ($k in $NAME2CODE.Keys) { if ($addr -like "*$k*") { return $NAME2CODE[$k] } }
  return $null
}
function Get-ApplyAll([string]$op, [int]$maxPages) {
  $rows = @(); $page = 1
  do {
    try { $r = Invoke-RestMethod "$applyBase/$op`?page=$page&perPage=1000&serviceKey=$keyEnc" -TimeoutSec 60 } catch { break }
    $d = @($r.data) | Where-Object { $_ }
    if (-not $d) { break }
    $rows += $d
    if ($d.Count -lt 1000 -or $page -ge $maxPages) { break }
    $page++
  } while ($true)
  return ,$rows
}

$applyCount = 0
if ($doApply) {
  Write-Host "  · 청약홈 공고 + 주택형(분양가) 수집..." -ForegroundColor Gray
  try {
    # (a) 공고 메타 — 수도권만, 분양(일반)은 2025년 이후 공고만
    $meta = @{}
    foreach ($spec in @(@('getRemndrLttotPblancDetail','무순위',3), @('getAPTLttotPblancDetail','분양',4))) {
      foreach ($it in (Get-ApplyAll $spec[0] $spec[2])) {
        $code = AddrToCode "$($it.HSSPLY_ADRES) $($it.SUBSCRPT_AREA_CODE_NM)"
        if (-not $code) { continue }
        $pd = "$($it.RCRIT_PBLANC_DE)".Trim()
        if ($spec[1] -eq '분양' -and ($pd -eq '' -or $pd -lt '2025-01-01')) { continue }
        $mvn = "$($it.MVN_PREARNGE_YM)".Trim(); if ($mvn -match '^\d{6}$') { $mvn = $mvn.Substring(0,4)+'-'+$mvn.Substring(4,2) } else { $mvn = $null }
        $units = 0; [void][int]::TryParse(("$($it.TOT_SUPLY_HSHLDCO)" -replace '[^\d]',''), [ref]$units)
        $meta["$($it.PBLANC_NO)"] = [pscustomobject]@{
          code=$code; apt=("$($it.HOUSE_NM)").Trim(); kind=$spec[1]; moveInYM=$mvn
          contractYM=$(if ($pd.Length -ge 7) { $pd.Substring(0,7) } else { $null })
          pblancUrl=("$($it.PBLANC_URL)").Trim(); supplyUnits=$units
        }
      }
    }
    # (b) 주택형별 분양가 — 공고별 대표(세대수 최다) 1개 선택
    $best = @{}
    foreach ($spec in @(@('getRemndrLttotPblancMdl',5), @('getAPTLttotPblancMdl',16))) {
      foreach ($m in (Get-ApplyAll $spec[0] $spec[1])) {
        $no = "$($m.PBLANC_NO)"; if (-not $meta.ContainsKey($no)) { continue }
        $price = 0
        foreach ($fld in 'LTTOT_TOP_AMOUNT','SUPLY_AMOUNT','LTTOT_AMOUNT') { $v = "$($m.$fld)" -replace '[^\d]',''; if ($v) { [void][int]::TryParse($v,[ref]$price); if ($price -gt 0) { break } } }
        $area = 0.0; [void][double]::TryParse("$($m.HOUSE_TY)", [ref]$area)
        if ($price -le 0 -or $area -le 0) { continue }
        $u = 0; [void][int]::TryParse(("$($m.SUPLY_HSHLDCO)" -replace '[^\d]',''), [ref]$u)
        if (-not $best.ContainsKey($no) -or $u -gt $best[$no].units) { $best[$no] = [pscustomobject]@{ areaM2=[math]::Round($area,2); priceManwon=$price; units=$u } }
      }
    }
    # (c) 결합 → items
    foreach ($no in $meta.Keys) {
      $mt = $meta[$no]; $b = if ($best.ContainsKey($no)) { $best[$no] } else { $null }
      $items.Add([pscustomobject][ordered]@{
        kind=$mt.kind; code=$mt.code; region=(RegName $mt.code); umd=''; apt=$mt.apt
        areaM2=$(if ($b) { $b.areaM2 } else { 0 }); floor=$null
        priceManwon=$(if ($b) { $b.priceManwon } else { 0 })
        dealDate=$null; contractYM=$mt.contractYM; moveInYM=$mt.moveInYM
        supplyUnits=$mt.supplyUnits; pblancUrl=$mt.pblancUrl
      })
      $applyCount++
    }
    Write-Host ("    수도권 공고 {0}건 (분양가 확보 {1}건)" -f $applyCount, $best.Count) -ForegroundColor DarkGray
  } catch { Write-Host ("    청약홈 수집 일부 실패: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow }
}

# ── presale.js 작성 ──────────────────────────────────────────────────────────
$silvCount = ($items | Where-Object { $_.kind -eq '분양권' }).Count
$out = [ordered]@{
  isSample  = $false
  updatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  stats     = @{ note = '청약홈 무순위/분양(분양가=주택형 공급금액) + 분양권 전매 실거래' }
  items     = $items.ToArray()
}
$json = $out | ConvertTo-Json -Depth 8
$content = "/* 자동 생성 — 직접 수정 금지. 「③ 분양·미분양 업데이트.bat」 실행 시 갱신됩니다. */`r`nwindow.PRESALE_DATA = $json;`r`n"
[System.IO.File]::WriteAllText($OutPath, $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "  ─── 업데이트 완료 ───────────────────────────────" -ForegroundColor Cyan
Write-Host ("   분양권 전매 실거래 : {0}건" -f $silvCount)
Write-Host ("   청약홈(무순위/분양): {0}건" -f $applyCount)
Write-Host ("   합계               : {0}건" -f $items.Count) -ForegroundColor Green
Write-Host ""
Write-Host "   → 「④ 분양 대시보드 열기.bat」 으로 결과를 확인하세요." -ForegroundColor Green
Write-Host ""
