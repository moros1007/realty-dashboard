/* ────────────────────────────────────────────────────────────────
   cheonho-sample.js — 천호역 접근 역세권 대시보드 예시(데모) 데이터
   실제 인증키로 cheonho_fetch.ps1 을 돌리면 data/cheonho.js 가 생성되어
   이 예시 대신 "국토부 실거래가 진짜 데이터"가 표시됩니다.
   ※ 아래는 2025~2026 실거래 조사치 기반 데모값(실제 최신 시세와 다를 수 있음).
   단위: amountManwon·jeonseManwon·gapManwon = 만원 / areaM2 = 전용㎡
──────────────────────────────────────────────────────────────── */
window.CHEONHO_SAMPLE = {
  isSample: true,
  updatedAt: "2026-06-03 (예시 데이터)",
  anchor: "천호역(5·8호선)",
  config: { capEok: 5, areaMin: 45, areaMax: 90, monthsBack: 4 },
  regionJeonse: {
    "송파":     { ratioPct: 51, jeonseManwon: 105000, saleManwon: 205000 },
    "강동":     { ratioPct: 53, jeonseManwon: 78000,  saleManwon: 147000 },
    "성남수정": { ratioPct: 58, jeonseManwon: 60000,  saleManwon: 103000 },
    "성남중원": { ratioPct: 60, jeonseManwon: 54000,  saleManwon: 90000  },
    "구리":     { ratioPct: 54, jeonseManwon: 46000,  saleManwon: 85000  },
    "남양주":   { ratioPct: 56, jeonseManwon: 45000,  saleManwon: 80000  }
  },
  items: [
    /* ── 송파 (서울=토지거래허가구역=갭 원칙 불가 / 평지) ── */
    { group:"송파", region:"송파", code:"11710", apt:"헬리오시티", umd:"가락동", areaM2:84.98, floor:15, amountManwon:243000, buildYear:2018, dealDate:"2026-05-22", dealType:"중개거래", jeonseManwon:120000, jeonseSrc:"complex", gapManwon:123000, isNew:true },
    { group:"송파", region:"송파", code:"11710", apt:"헬리오시티", umd:"가락동", areaM2:59.96, floor:22, amountManwon:184000, buildYear:2018, dealDate:"2026-05-09", dealType:"중개거래", jeonseManwon:92000,  jeonseSrc:"complex", gapManwon:92000,  isNew:true },
    { group:"송파", region:"송파", code:"11710", apt:"올림픽훼미리타운", umd:"문정동", areaM2:84.81, floor:7, amountManwon:172000, buildYear:1988, dealDate:"2026-04-18", dealType:"중개거래", jeonseManwon:80000, jeonseSrc:"complex", gapManwon:92000, isNew:false },
    { group:"송파", region:"송파", code:"11710", apt:"송파파인타운13단지", umd:"장지동", areaM2:84.92, floor:5, amountManwon:135000, buildYear:2008, dealDate:"2026-04-30", dealType:"중개거래", jeonseManwon:68000, jeonseSrc:"complex", gapManwon:67000, isNew:false },
    { group:"송파", region:"송파", code:"11710", apt:"송파파인타운7단지", umd:"장지동", areaM2:59.94, floor:9, amountManwon:108000, buildYear:2008, dealDate:"2026-03-25", dealType:"중개거래", jeonseManwon:58000, jeonseSrc:"complex", gapManwon:50000, isNew:false },
    { group:"송파", region:"송파", code:"11710", apt:"e편한세상송파파크센트럴", umd:"거여동", areaM2:84.96, floor:12, amountManwon:163000, buildYear:2020, dealDate:"2026-04-12", dealType:"중개거래", jeonseManwon:82000, jeonseSrc:"complex", gapManwon:81000, isNew:false },
    { group:"송파", region:"송파", code:"11710", apt:"올림픽선수기자촌", umd:"방이동", areaM2:83.06, floor:3, amountManwon:228000, buildYear:1988, dealDate:"2026-03-08", dealType:"중개거래", jeonseManwon:95000, jeonseSrc:"complex", gapManwon:133000, isNew:false },

    /* ── 강동 (서울=토허구역 / 천호역 코앞·평지) ── */
    { group:"강동", region:"강동", code:"11740", apt:"래미안강동팰리스", umd:"천호동", areaM2:84.93, floor:14, amountManwon:163000, buildYear:2017, dealDate:"2026-05-20", dealType:"중개거래", jeonseManwon:82000, jeonseSrc:"complex", gapManwon:81000, isNew:true },
    { group:"강동", region:"강동", code:"11740", apt:"강동롯데캐슬퍼스트", umd:"성내동", areaM2:84.99, floor:9, amountManwon:152000, buildYear:2008, dealDate:"2026-04-26", dealType:"중개거래", jeonseManwon:78000, jeonseSrc:"complex", gapManwon:74000, isNew:false },
    { group:"강동", region:"강동", code:"11740", apt:"e편한세상강동에코포레", umd:"성내동", areaM2:59.97, floor:11, amountManwon:118000, buildYear:2017, dealDate:"2026-04-05", dealType:"중개거래", jeonseManwon:62000, jeonseSrc:"complex", gapManwon:56000, isNew:false },
    { group:"강동", region:"강동", code:"11740", apt:"고덕그라시움", umd:"고덕동", areaM2:84.24, floor:20, amountManwon:182000, buildYear:2019, dealDate:"2026-05-02", dealType:"중개거래", jeonseManwon:88000, jeonseSrc:"complex", gapManwon:94000, isNew:true },
    { group:"강동", region:"강동", code:"11740", apt:"래미안솔베뉴", umd:"명일동", areaM2:84.95, floor:6, amountManwon:171000, buildYear:2019, dealDate:"2026-03-19", dealType:"중개거래", jeonseManwon:84000, jeonseSrc:"complex", gapManwon:87000, isNew:false },

    /* ── 성남(수정·중원) = 토허구역 / 8호선 본시가지 = 급경사 ⚠ ── */
    { group:"성남", region:"성남수정", code:"41131", apt:"산성역자이푸르지오2단지", umd:"신흥동", areaM2:84.93, floor:14, amountManwon:110000, buildYear:2020, dealDate:"2026-05-10", dealType:"중개거래", jeonseManwon:62000, jeonseSrc:"complex", gapManwon:48000, isNew:true },
    { group:"성남", region:"성남수정", code:"41131", apt:"e편한세상금빛그랑메종", umd:"신흥동", areaM2:59.98, floor:8, amountManwon:88000, buildYear:2022, dealDate:"2026-04-15", dealType:"중개거래", jeonseManwon:52000, jeonseSrc:"complex", gapManwon:36000, isNew:false },
    { group:"성남", region:"성남수정", code:"41131", apt:"위례더힐55", umd:"창곡동", areaM2:84.97, floor:7, amountManwon:138000, buildYear:2016, dealDate:"2026-04-22", dealType:"중개거래", jeonseManwon:72000, jeonseSrc:"complex", gapManwon:66000, isNew:false },
    { group:"성남", region:"성남중원", code:"41133", apt:"e편한세상금광", umd:"금광동", areaM2:84.96, floor:10, amountManwon:92000, buildYear:2022, dealDate:"2026-03-28", dealType:"중개거래", jeonseManwon:55000, jeonseSrc:"complex", gapManwon:37000, isNew:false },

    /* ── 별내선(구리·다산·별내) = 비규제 → 갭(전세끼고 3~4년) 가능 ✓ / 평지 신도시 ── */
    { group:"별내선", region:"남양주", code:"41360", apt:"다산자이아이비플레이스", umd:"지금동", areaM2:84.97, floor:12, amountManwon:92000, buildYear:2021, dealDate:"2026-05-18", dealType:"중개거래", jeonseManwon:50000, jeonseSrc:"complex", gapManwon:42000, isNew:true },
    { group:"별내선", region:"남양주", code:"41360", apt:"다산한양수자인리버팰리스", umd:"도농동", areaM2:84.88, floor:9, amountManwon:88000, buildYear:2019, dealDate:"2026-04-29", dealType:"중개거래", jeonseManwon:48000, jeonseSrc:"complex", gapManwon:40000, isNew:false },
    { group:"별내선", region:"남양주", code:"41360", apt:"별내자이더스타", umd:"별내동", areaM2:84.95, floor:18, amountManwon:86000, buildYear:2023, dealDate:"2026-05-06", dealType:"중개거래", jeonseManwon:46000, jeonseSrc:"complex", gapManwon:40000, isNew:true },
    { group:"별내선", region:"남양주", code:"41360", apt:"별내푸르지오", umd:"별내동", areaM2:59.91, floor:7, amountManwon:62000, buildYear:2012, dealDate:"2026-03-30", dealType:"중개거래", jeonseManwon:37000, jeonseSrc:"complex", gapManwon:25000, isNew:false },
    { group:"별내선", region:"구리", code:"41310", apt:"e편한세상인창어반포레", umd:"인창동", areaM2:84.92, floor:11, amountManwon:101000, buildYear:2022, dealDate:"2026-05-12", dealType:"중개거래", jeonseManwon:52000, jeonseSrc:"complex", gapManwon:49000, isNew:true },
    { group:"별내선", region:"구리", code:"41310", apt:"구리역롯데캐슬", umd:"교문동", areaM2:84.79, floor:5, amountManwon:78000, buildYear:2003, dealDate:"2026-03-21", dealType:"중개거래", jeonseManwon:45000, jeonseSrc:"complex", gapManwon:33000, isNew:false }
  ]
};
