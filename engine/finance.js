/* ============================================================================
 *  finance.js  —  분양/분양권 자금계획 계산 엔진 (순수 함수)
 *  ──────────────────────────────────────────────────────────────────────────
 *  · 초기 필요자금(계약금+프리미엄) / 입주 시 추가자금
 *  · 대출 가능액 = min( LTV한도 , 수도권 절대한도 , DSR한도 )
 *  · 월 납부예상금액(원리금균등) + 중도금대출 이자(이자후불제)
 *  · 자금 소요 시기 타임라인(계약 → 중도금 N회 → 잔금/입주)
 *  모든 금액 단위: 만원
 * ========================================================================== */
(function () {
  'use strict';
  var F = window.REG.FINANCE;

  /* 원리금균등 월상환액 (만원). P 원금, 연이율%, 년수 */
  function amortizedMonthly(P, annualPct, years) {
    if (P <= 0 || years <= 0) return 0;
    var n = years * 12, r = (annualPct / 100) / 12;
    if (r === 0) return P / n;
    var f = Math.pow(1 + r, n);
    return P * r * f / (f - 1);
  }
  /* 월상환액으로 빌릴 수 있는 최대 원금 (DSR 역산) */
  function maxPrincipalByMonthly(monthly, annualPct, years) {
    if (monthly <= 0 || years <= 0) return 0;
    var n = years * 12, r = (annualPct / 100) / 12;
    if (r === 0) return monthly * n;
    var f = Math.pow(1 + r, n);
    return monthly * (f - 1) / (r * f);
  }

  /* 수도권 주담대 절대한도 (시가 구간) */
  function loanCap(priceManwon) {
    var t = F.loanCapTiers, i;
    for (i = 0; i < t.length; i++) if (priceManwon <= t[i].maxPriceManwon) return t[i].capManwon;
    return t[t.length - 1].capManwon;
  }

  /* 대출 가능액 종합: LTV · 절대한도 · DSR 중 최솟값 */
  function loanAvailable(priceManwon, opt) {
    var regulated = opt.regulated;
    var ltv = regulated ? F.ltvRegulated : F.ltvNonReg;
    var byLtv = priceManwon * ltv;
    var byCap = regulated || opt.metro ? loanCap(priceManwon) : Infinity; // 수도권 전역 절대한도 적용
    // DSR: 스트레스 금리(현재금리 + 하한 3.0%p)로 한도 산정
    var qualRate = opt.ratePct + (opt.stressForDsr === false ? 0 : F.stressRateFloorPct);
    var monthlyCap = (opt.annualIncomeManwon * F.dsrLimit) / 12 - (opt.otherDebtMonthly || 0);
    var byDsr = opt.annualIncomeManwon > 0 ? maxPrincipalByMonthly(Math.max(0, monthlyCap), qualRate, opt.termYears) : Infinity;
    var finalLoan = Math.max(0, Math.min(byLtv, byCap, byDsr));
    var bind = finalLoan === byDsr && byDsr < byLtv && byDsr < byCap ? 'DSR'
      : finalLoan === byCap && byCap <= byLtv ? '절대한도'
      : 'LTV';
    return {
      ltvPct: ltv * 100, byLtv: Math.round(byLtv),
      byCap: byCap === Infinity ? null : Math.round(byCap),
      byDsr: byDsr === Infinity ? null : Math.round(byDsr),
      qualRatePct: +qualRate.toFixed(2),
      finalManwon: Math.round(finalLoan), binding: bind
    };
  }

  /* YYYY-MM 문자열 ± 개월 */
  function addMonthsYM(ym, add) {
    var p = ('' + ym).split('-'), y = +p[0], m = +p[1] - 1 + add;
    y += Math.floor(m / 12); m = ((m % 12) + 12) % 12;
    return y + '-' + ('0' + (m + 1)).slice(-2);
  }
  function nowYM() { var d = new Date(); return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2); }

  /* 종합 자금계획 */
  function buildPlan(item, p) {
    var REG = window.REG;
    var code = item.code;
    var regulated = REG.isRegulated(code);
    var metro = REG.isMetroOverconc(code);
    var P = item.priceManwon || 0;
    var area = item.areaM2 || 0;

    var contractPct = p.contractPct != null ? p.contractPct : 0.10;
    var midPct = p.midPct != null ? p.midPct : 0.60;
    var balancePct = p.balancePct != null ? p.balancePct : (1 - contractPct - midPct);
    var midRounds = p.midRounds || 6;
    var premium = p.premiumManwon || 0;

    var contract = P * contractPct;          // 계약금
    var mid = P * midPct;                     // 중도금(총)
    var balance = P * balancePct;             // 잔금
    var midPerRound = mid / midRounds;

    var tax = REG.acquisitionTax(P, area, p.homeCountAfter || 1, regulated);

    var loan = loanAvailable(P, {
      regulated: regulated, metro: metro, ratePct: p.ratePct, termYears: p.termYears,
      annualIncomeManwon: p.annualIncomeManwon || 0, otherDebtMonthly: p.otherDebtMonthly || 0,
      stressForDsr: p.stressForDsr
    });

    var totalCost = P + tax.totalManwon + premium;          // 총 매입원가
    var equityNeeded = Math.max(0, totalCost - loan.finalManwon); // 필요 자기자본
    var upfrontCash = contract + premium;                    // 계약 시 현금 소요
    var atMoveInCash = Math.max(0, equityNeeded - upfrontCash); // 입주(잔금) 시 추가 현금
    var feasible = (p.cashManwon || 0) >= equityNeeded;
    var surplus = (p.cashManwon || 0) - equityNeeded;       // +여유 / −부족

    // 월 납부: 입주 후 잔금 주담대 원리금균등 (실제 실행액 = min(가능액, 부족분))
    var actualLoan = Math.min(loan.finalManwon, Math.max(0, totalCost - (p.cashManwon || 0)));
    var monthlyAfter = amortizedMonthly(actualLoan, p.ratePct, p.termYears);
    var monthlyAtMaxLoan = amortizedMonthly(loan.finalManwon, p.ratePct, p.termYears);

    // 중도금대출 이자(이자후불제): 회차별 누적잔액에 대한 이자, 대표 월이자 = 총이자/기간
    var midLoanRate = (p.midLoanRatePct != null ? p.midLoanRatePct : F.midLoanRatePct) / 100 / 12;
    var midInterestFree = p.midInterestMode === 'free';

    // 타임라인 (상세 패널 전용 — 표/KPI 대량 계산 시 p.withTimeline=false 로 생략해 성능 확보)
    var startYM = item.contractYM || nowYM();
    var moveInYM = item.moveInYM || addMonthsYM(startYM, 30); // 미상 시 분양~입주 30개월 가정
    var timeline = [], midInterestTotal = 0, midMonthlyRepresentative = 0;
    if (p.withTimeline) {
      var span = Math.max(midRounds + 1, monthsBetween(startYM, moveInYM));
      var step = Math.max(1, Math.round((span - 2) / midRounds));
      timeline.push({ ym: startYM, label: '계약', cashManwon: Math.round(upfrontCash), note: '계약금' + (premium ? ' + 프리미엄' : '') });
      var cumMidLoan = 0;
      for (var i = 1; i <= midRounds; i++) {
        var ym = addMonthsYM(startYM, i * step);
        if (monthsBetween(ym, moveInYM) < 1) ym = addMonthsYM(moveInYM, -1);
        cumMidLoan += midPerRound;                  // 중도금 전액 대출 가정
        var roundInterest = midInterestFree ? 0 : cumMidLoan * midLoanRate * step;
        midInterestTotal += roundInterest;
        timeline.push({
          ym: ym, label: '중도금 ' + i + '/' + midRounds,
          cashManwon: Math.round(midInterestFree ? 0 : roundInterest),
          note: midInterestFree ? '무이자(대출)' : '중도금대출 이자(후불)'
        });
      }
      timeline.push({
        ym: moveInYM, label: '잔금·입주',
        cashManwon: Math.round(atMoveInCash),
        note: '잔금 + 취득세 − 주담대 / 주담대 실행, 실거주의무 시작'
      });
      midMonthlyRepresentative = midInterestFree ? 0 : Math.round(midInterestTotal / Math.max(1, monthsBetween(startYM, moveInYM)));
    }

    return {
      regulated: regulated, metro: metro,
      priceManwon: P,
      breakdown: { contract: Math.round(contract), mid: Math.round(mid), balance: Math.round(balance), midPerRound: Math.round(midPerRound) },
      tax: tax,
      loan: loan, actualLoanManwon: Math.round(actualLoan),
      totalCostManwon: Math.round(totalCost),
      equityNeededManwon: Math.round(equityNeeded),
      upfrontCashManwon: Math.round(upfrontCash),
      atMoveInCashManwon: Math.round(atMoveInCash),
      feasible: feasible, surplusManwon: Math.round(surplus),
      monthlyAfterManwon: Math.round(monthlyAfter),
      monthlyAtMaxLoanManwon: Math.round(monthlyAtMaxLoan),
      midInterestTotalManwon: Math.round(midInterestTotal),
      midMonthlyManwon: midMonthlyRepresentative,
      midInterestFree: midInterestFree,
      startYM: startYM, moveInYM: moveInYM, timeline: timeline
    };
  }

  function monthsBetween(a, b) {
    var pa = ('' + a).split('-'), pb = ('' + b).split('-');
    return (+pb[0] - +pa[0]) * 12 + (+pb[1] - +pa[1]);
  }

  window.FIN = {
    amortizedMonthly: amortizedMonthly,
    maxPrincipalByMonthly: maxPrincipalByMonthly,
    loanCap: loanCap, loanAvailable: loanAvailable,
    addMonthsYM: addMonthsYM, monthsBetween: monthsBetween, nowYM: nowYM,
    buildPlan: buildPlan
  };
})();
