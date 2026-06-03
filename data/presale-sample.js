/* ────────────────────────────────────────────────────────────────
   presale-sample.js — 수도권 미분양·분양권 예시(데모) 데이터
   ※ 실제 인증키로 분양fetch.ps1 을 돌리면 data/presale.js 가 생성되어
     이 예시 대신 '진짜 데이터(분양권 실거래 + 청약홈 무순위)'가 표시됩니다.
   ※ 아래 단지·가격은 2025~2026 시세를 참고한 데모용 가공치이며 실제와 다릅니다.
   단위: priceManwon = 만원(분양가 또는 분양권 거래가), areaM2 = 전용면적(㎡)
   kind: '분양권'(전매 실거래) | '무순위'(무순위·잔여세대) | '분양'(신규) | '미분양'(준공후)
──────────────────────────────────────────────────────────────── */
window.PRESALE_SAMPLE = {
  isSample: true,
  updatedAt: "2026-06-03 15:00 (예시 데이터)",
  // 미분양 통계(국토부, 2025-11 기준 참고치) — 지역 맥락 표시용
  stats: {
    asOf: "2025-11",
    nationalUnsold: 68794,
    metroUnsold: 16535,
    afterCompletionMetro: 4120   // 수도권 준공후 미분양(참고치)
  },
  items: [
    // ── 분양권 전매 실거래 (규제지역: 서울·경기12곳) ──────────────────────────
    { kind:"분양권", code:"11680", umd:"개포동", apt:"디에이치퍼스티어아이파크", areaM2:84.97, floor:18, priceManwon:340000, dealDate:"2026-05-20", contractYM:"2024-03", moveInYM:"2026-11", priceCap:true },
    { kind:"분양권", code:"11710", umd:"신천동", apt:"잠실르엘", areaM2:84.93, floor:22, priceManwon:265000, dealDate:"2026-05-14", contractYM:"2024-11", moveInYM:"2027-08", priceCap:true },
    { kind:"분양권", code:"41210", umd:"광명동", apt:"광명자이더샵포레나", areaM2:84.98, floor:12, priceManwon:135000, dealDate:"2026-05-22", contractYM:"2023-09", moveInYM:"2026-09" },
    { kind:"분양권", code:"41117", umd:"망포동", apt:"영통자이센트럴파크", areaM2:84.96, floor:9, priceManwon:98000, dealDate:"2026-05-09", contractYM:"2023-05", moveInYM:"2026-07" },
    { kind:"분양권", code:"41173", umd:"비산동", apt:"평촌엘프라우드", areaM2:84.99, floor:15, priceManwon:112000, dealDate:"2026-04-28", contractYM:"2022-12", moveInYM:"2026-06" },
    { kind:"분양권", code:"41465", umd:"성복동", apt:"수지구청역롯데캐슬", areaM2:84.70, floor:7, priceManwon:104000, dealDate:"2026-04-19", contractYM:"2023-02", moveInYM:"2026-08" },
    { kind:"분양권", code:"41450", umd:"학암동", apt:"하남감일푸르지오", areaM2:84.92, floor:11, priceManwon:118000, dealDate:"2026-04-11", contractYM:"2023-06", moveInYM:"2026-10" },

    // ── 분양권 전매 실거래 (비규제 수도권) ────────────────────────────────────
    { kind:"분양권", code:"41590", umd:"오산동", apt:"동탄레이크파크자연앤이편한세상", areaM2:84.95, floor:14, priceManwon:89000, dealDate:"2026-05-18", contractYM:"2023-04", moveInYM:"2026-12" },
    { kind:"분양권", code:"28185", umd:"송도동", apt:"송도자이더스타", areaM2:84.98, floor:25, priceManwon:96000, dealDate:"2026-05-12", contractYM:"2023-07", moveInYM:"2027-01" },
    { kind:"분양권", code:"28260", umd:"당하동", apt:"검단신도시제일풍경채", areaM2:84.91, floor:8, priceManwon:62000, dealDate:"2026-05-06", contractYM:"2023-10", moveInYM:"2026-09" },
    { kind:"분양권", code:"41570", umd:"마산동", apt:"김포한강신도시중흥S클래스", areaM2:84.88, floor:6, priceManwon:58000, dealDate:"2026-04-30", contractYM:"2023-08", moveInYM:"2026-11" },

    // ── 무순위 / 잔여세대 (청약홈) = 실시간 매수 가능 (미분양성) ────────────────
    { kind:"무순위", code:"11740", umd:"둔촌동", apt:"올림픽파크포레온(잔여)", areaM2:84.95, priceManwon:182000, contractYM:"2026-05", moveInYM:"2026-11", supplyUnits:8, remainUnits:8, priceCap:true },
    { kind:"무순위", code:"28260", umd:"불로동", apt:"검단신도시예미지(무순위)", areaM2:84.90, priceManwon:54000, contractYM:"2026-05", moveInYM:"2026-08", supplyUnits:34, remainUnits:34 },
    { kind:"무순위", code:"41590", umd:"장지동", apt:"동탄2신도시포레나(잔여)", areaM2:74.98, priceManwon:67000, contractYM:"2026-04", moveInYM:"2026-10", supplyUnits:12, remainUnits:12 },
    { kind:"무순위", code:"41360", umd:"다산동", apt:"남양주왕숙린네뜨(무순위)", areaM2:84.93, priceManwon:71000, contractYM:"2026-05", moveInYM:"2027-03", supplyUnits:21, remainUnits:21 },

    // ── 준공후 미분양 (외곽, 즉시 입주 가능) ─────────────────────────────────
    { kind:"미분양", code:"41220", umd:"고덕면", apt:"평택고덕국제신도시A블록", areaM2:84.96, priceManwon:52000, contractYM:"2026-05", moveInYM:"2025-12", supplyUnits:120, remainUnits:73 },
    { kind:"미분양", code:"41550", umd:"공도읍", apt:"안성공도센트럴카운티", areaM2:59.94, priceManwon:31000, contractYM:"2026-05", moveInYM:"2025-09", supplyUnits:88, remainUnits:61 },
    { kind:"미분양", code:"41630", umd:"옥정동", apt:"양주옥정대광로제비앙", areaM2:84.92, priceManwon:46000, contractYM:"2026-05", moveInYM:"2025-11", supplyUnits:150, remainUnits:42 },
    { kind:"미분양", code:"41480", umd:"동패동", apt:"운정신도시중흥S클래스", areaM2:84.95, priceManwon:55000, contractYM:"2026-05", moveInYM:"2026-02", supplyUnits:96, remainUnits:28 },
    { kind:"미분양", code:"28710", umd:"길상면", apt:"강화미분양테스트단지", areaM2:74.90, priceManwon:29000, contractYM:"2026-05", moveInYM:"2025-06", supplyUnits:60, remainUnits:39 },

    // ── 신규 분양 (청약 예정/진행) ───────────────────────────────────────────
    { kind:"분양", code:"41135", umd:"대장동", apt:"분당대장지구신혼희망(분양)", areaM2:84.98, priceManwon:128000, contractYM:"2026-07", moveInYM:"2029-03", supplyUnits:420, priceCap:true, publicLand:true },
    { kind:"분양", code:"41450", umd:"교산동", apt:"하남교산공공분양", areaM2:84.96, priceManwon:96000, contractYM:"2026-08", moveInYM:"2029-06", supplyUnits:680, priceCap:true, publicLand:true }
  ]
};
