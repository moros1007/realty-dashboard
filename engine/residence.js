/* ============================================================================
 *  residence.js  —  실거주의무 · 전매제한 분류 엔진
 *  ──────────────────────────────────────────────────────────────────────────
 *  「10·15 대책」 기준:
 *   · 규제지역 = 서울 전역 + 경기 12곳 = 토지거래허가구역
 *     → 매수 시 '실거주 목적'만 허가 → 사실상 2년 실거주의무(2025-10-20 계약분~)
 *   · 분양가상한제 적용 주택 → 별도 실거주의무(민간 2년 / 공공 ~3년) + 전매제한
 *   · 분양권 전매제한: 규제지역/분양가상한제 수도권 최대 36개월(단지별 상이)
 *  ※ 단지별 실제 의무는 입주자모집공고문이 최종 — 본 분류는 '지역·유형 기반 추정'.
 * ========================================================================== */
(function () {
  'use strict';
  var REG = window.REG, R = REG.RESIDENCE, RS = REG.RESALE;

  /* item.kind: '분양권' | '무순위' | '분양' | '미분양'
     item.priceCap: 분양가상한제 적용(true/false/undefined)
     item.publicLand: 공공택지 여부(true/false) */
  function classify(item) {
    var code = item.code;
    var regulated = REG.isRegulated(code);
    var metro = REG.isMetroOverconc(code);
    var priceCap = item.priceCap === true || (regulated && (item.kind === '분양' || item.kind === '무순위' || item.kind === '미분양'));
    var publicLand = item.publicLand === true;

    // ── 실거주의무 ──────────────────────────────────────────────
    var years = 0, basis = [];
    if (regulated) { years = Math.max(years, R.regulatedToheoYears); basis.push('토지거래허가구역(2년)'); }
    if (priceCap) {
      var pcY = publicLand ? R.priceCapPublicYears : R.priceCapPrivateYears;
      years = Math.max(years, pcY);
      basis.push('분양가상한제(' + (publicLand ? '공공택지' : '민간택지') + ' ' + pcY + '년)');
    }
    var hasDuty = years > 0;

    // ── 전매제한 ────────────────────────────────────────────────
    var resaleMonths, resaleBasis;
    if (regulated || priceCap) { resaleMonths = RS.regulatedMonths; resaleBasis = '규제지역/분양가상한제'; }
    else if (metro) { resaleMonths = RS.metroOverconcMonths; resaleBasis = '수도권 과밀억제권역'; }
    else { resaleMonths = RS.otherMonths; resaleBasis = '그 외 수도권'; }

    // ── 분양권 거래 가능 여부(전매 관점) ─────────────────────────
    // 분양권 실거래(전매)로 잡힌 물량은 '전매가 이뤄진(가능한)' 물량이지만,
    // 규제지역은 전매제한이 강해 일반적으로 제한적 → 안내 문구로 표기.
    var tradeNote;
    if (item.kind === '분양권') {
      tradeNote = regulated
        ? '규제지역 — 전매제한·실거주의무 확인 필수(예외적 전매만 가능)'
        : '전매 가능 물량(신고 실거래 기준)';
    } else if (item.kind === '무순위' || item.kind === '미분양') {
      tradeNote = '청약 없이/잔여세대 — 매수 즉시 가능' + (regulated ? ', 단 실거주의무 적용' : '');
    } else {
      tradeNote = '신규 분양(청약) 물량';
    }

    return {
      regulated: regulated, metro: metro, priceCap: priceCap, publicLand: publicLand,
      hasDuty: hasDuty, dutyYears: years, dutyBasis: basis,
      resaleMonths: resaleMonths, resaleBasis: resaleBasis,
      tradeNote: tradeNote,
      enforceFrom: R.enforceFromContract,
      // UI 배지
      badges: buildBadges(item.kind, regulated, hasDuty, years, priceCap)
    };
  }

  function buildBadges(kind, regulated, hasDuty, years, priceCap) {
    var b = [];
    b.push({ text: kind, cls: 'b-kind-' + kind });
    if (regulated) b.push({ text: '규제지역', cls: 'b-reg' });
    if (priceCap) b.push({ text: '분상제', cls: 'b-pc' });
    b.push(hasDuty
      ? { text: '실거주 ' + years + '년', cls: 'b-duty' }
      : { text: '실거주의무 없음', cls: 'b-free' });
    return b;
  }

  window.RES = { classify: classify };
})();
