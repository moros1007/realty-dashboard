/* ────────────────────────────────────────────────────────────────
   sample.js  —  예시(데모) 데이터
   실제 인증키로 fetch.ps1 을 한 번이라도 돌리면 data/latest.js 가
   생성되어 이 예시 대신 "실거래가 진짜 데이터"가 표시됩니다.

   ※ 아래 값은 2025~2026 실제 실거래가 조사치를 바탕으로 만든 데모용 샘플이며,
     실제 최신 시세와 다를 수 있습니다. 진짜 데이터는 인증키 발급 후 확인하세요.
   금액 단위: amountManwon = 만원  /  areaM2 = 전용면적(㎡)
──────────────────────────────────────────────────────────────── */
window.REALTY_SAMPLE = {
  isSample: true,
  updatedAt: "2026-06-03 15:00 (예시 데이터)",
  config: { priceMaxEok: 16, areaMin: 80, areaMax: 102 },

  // 내 집(매도 예정) — 산성역자이푸르지오 (성남 수정구 신흥동)
  myHome: {
    label: "산성역자이푸르지오",
    addr: "성남시 수정구 신흥동",
    items: [
      { apt: "산성역자이푸르지오2단지", umd: "신흥동", areaM2: 84.93, floor: 14, amountManwon: 110000, buildYear: 2020, dealDate: "2026-05-10", dealType: "중개거래" },
      { apt: "산성역자이푸르지오2단지", umd: "신흥동", areaM2: 84.98, floor: 9,  amountManwon: 108500, buildYear: 2020, dealDate: "2026-03-22", dealType: "중개거래" },
      { apt: "산성역자이푸르지오3단지", umd: "신흥동", areaM2: 84.93, floor: 5,  amountManwon: 105000, buildYear: 2020, dealDate: "2026-02-08", dealType: "중개거래" },
      { apt: "산성역자이푸르지오2단지", umd: "신흥동", areaM2: 84.93, floor: 18, amountManwon: 112000, buildYear: 2020, dealDate: "2025-12-15", dealType: "중개거래" }
    ]
  },

  // 타겟 지역 실거래 (분당 / 평촌 / 과천)
  items: [
    // ── 분당 (성남 분당구 41135) ──
    { region: "분당", code: "41135", apt: "구미동 무지개마을4단지",  umd: "구미동", areaM2: 84.93, floor: 3,  amountManwon: 119000, buildYear: 1995, dealDate: "2026-05-21", dealType: "중개거래", isNew: true },
    { region: "분당", code: "41135", apt: "야탑동 장미마을현대",     umd: "야탑동", areaM2: 84.96, floor: 9,  amountManwon: 132000, buildYear: 1995, dealDate: "2026-05-18", dealType: "중개거래", isNew: true },
    { region: "분당", code: "41135", apt: "금곡동 청솔마을주공9단지", umd: "금곡동", areaM2: 84.59, floor: 5,  amountManwon: 138000, buildYear: 1995, dealDate: "2026-04-27", dealType: "중개거래" },
    { region: "분당", code: "41135", apt: "이매동 이매촌한신",       umd: "이매동", areaM2: 84.88, floor: 7,  amountManwon: 155000, buildYear: 1992, dealDate: "2026-04-11", dealType: "중개거래" },
    { region: "분당", code: "41135", apt: "수내동 양지마을금호",     umd: "수내동", areaM2: 84.69, floor: 2,  amountManwon: 158000, buildYear: 1992, dealDate: "2026-03-30", dealType: "중개거래" },
    { region: "분당", code: "41135", apt: "정자동 정자아이파크",     umd: "정자동", areaM2: 84.97, floor: 16, amountManwon: 172000, buildYear: 2004, dealDate: "2026-03-12", dealType: "중개거래" },
    { region: "분당", code: "41135", apt: "서현동 시범한양",         umd: "서현동", areaM2: 84.72, floor: 12, amountManwon: 185000, buildYear: 1991, dealDate: "2026-02-19", dealType: "중개거래" },

    // ── 평촌 (안양 동안구 41173) ──
    { region: "평촌", code: "41173", apt: "호계동 평촌어바인퍼스트",  umd: "호계동", areaM2: 84.97, floor: 15, amountManwon: 135000, buildYear: 2021, dealDate: "2026-05-24", dealType: "중개거래", isNew: true },
    { region: "평촌", code: "41173", apt: "평촌동 향촌현대4차",      umd: "평촌동", areaM2: 84.69, floor: 11, amountManwon: 105000, buildYear: 1993, dealDate: "2026-05-09", dealType: "중개거래", isNew: true },
    { region: "평촌", code: "41173", apt: "평촌동 꿈마을금호",        umd: "평촌동", areaM2: 84.99, floor: 4,  amountManwon: 102000, buildYear: 1993, dealDate: "2026-04-20", dealType: "중개거래" },
    { region: "평촌", code: "41173", apt: "호계동 무궁화경남",        umd: "호계동", areaM2: 84.93, floor: 8,  amountManwon: 98000,  buildYear: 1994, dealDate: "2026-04-03", dealType: "중개거래" },
    { region: "평촌", code: "41173", apt: "평촌동 초원세경",          umd: "평촌동", areaM2: 84.36, floor: 3,  amountManwon: 92000,  buildYear: 1993, dealDate: "2026-03-15", dealType: "중개거래" },
    { region: "평촌", code: "41173", apt: "비산동 관악산뜨란채",      umd: "비산동", areaM2: 84.55, floor: 6,  amountManwon: 89000,  buildYear: 2004, dealDate: "2026-02-26", dealType: "중개거래" },

    // ── 과천 (과천시 41290) ──
    { region: "과천", code: "41290", apt: "별양동 과천래미안슈르",        umd: "별양동", areaM2: 84.97, floor: 4,  amountManwon: 198000, buildYear: 2008, dealDate: "2026-05-19", dealType: "중개거래", isNew: true },
    { region: "과천", code: "41290", apt: "부림동 과천센트럴파크푸르지오써밋", umd: "부림동", areaM2: 84.99, floor: 7,  amountManwon: 240000, buildYear: 2020, dealDate: "2026-04-28", dealType: "중개거래" },
    { region: "과천", code: "41290", apt: "원문동 과천위버필드",          umd: "원문동", areaM2: 84.98, floor: 12, amountManwon: 265000, buildYear: 2020, dealDate: "2026-04-08", dealType: "중개거래" },
    { region: "과천", code: "41290", apt: "중앙동 과천푸르지오써밋",       umd: "중앙동", areaM2: 84.94, floor: 18, amountManwon: 280000, buildYear: 2020, dealDate: "2026-03-21", dealType: "중개거래" },
    { region: "과천", code: "41290", apt: "원문동 과천위버필드(59㎡)",     umd: "원문동", areaM2: 59.98, floor: 9,  amountManwon: 215000, buildYear: 2020, dealDate: "2026-03-05", dealType: "중개거래" }
  ]
};
