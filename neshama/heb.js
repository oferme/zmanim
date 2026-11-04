// לוח נשמה – חישובי לוח עברי: המרת תאריכים, יארצייט, גימטריה ושקיעה. משותף למסך ולאפליקציה.
// חודשים (כמו ב-Hebcal): 1 ניסן … 6 אלול, 7 תשרי, 8 חשון, 9 כסלו, 10 טבת, 11 שבט, 12 אדר / אדר א, 13 אדר ב
(function (G) {
  'use strict';
  var EPOCH = -1373428;   // יום "0" של הספירה העברית במניין הימים הקבוע (RD)
  function elapsed(y) {   // ימים מתחילת הספירה עד א' תשרי (כולל דחיית לא אד"ו)
    var m = Math.floor((235 * y - 234) / 19), parts = 12084 + 13753 * m, d = 29 * m + Math.floor(parts / 25920);
    if ((3 * (d + 1)) % 7 < 3) d++;
    return d;
  }
  function delay(y) { var a = elapsed(y - 1), b = elapsed(y), c = elapsed(y + 1); return c - b === 356 ? 2 : (b - a === 382 ? 1 : 0); }
  function newYear(y) { return EPOCH + elapsed(y) + delay(y) + 1; }   // א' תשרי (RD)
  function yearLen(y) { return newYear(y + 1) - newYear(y); }
  function leap(y) { return (7 * y + 1) % 19 < 7; }
  function months(y) { return leap(y) ? 13 : 12; }
  function longCheshvan(y) { return yearLen(y) % 10 === 5; }
  function shortKislev(y) { return yearLen(y) % 10 === 3; }
  function monthDays(m, y) {
    if (m === 2 || m === 4 || m === 6 || m === 10 || m === 13) return 29;
    if (m === 12 && !leap(y)) return 29;
    if (m === 8 && !longCheshvan(y)) return 29;
    if (m === 9 && shortKislev(y)) return 29;
    return 30;
  }
  // תאריך עברי → מספר יום. יום שגדול ממספר הימים בחודש "גולש" לחודש הבא (כמו ב-Hebcal)
  function toAbs(y, m, d) {
    var t = d, i;
    if (m < 7) { for (i = 7; i <= months(y); i++) t += monthDays(i, y); for (i = 1; i < m; i++) t += monthDays(i, y); }
    else for (i = 7; i < m; i++) t += monthDays(i, y);
    return newYear(y) + t - 1;
  }
  function fromAbs(abs) {
    var y = Math.floor((abs - EPOCH) / 365.2468) + 1;
    while (newYear(y) > abs) y--;
    while (newYear(y + 1) <= abs) y++;
    var m = abs < toAbs(y, 1, 1) ? 7 : 1;
    while (abs > toAbs(y, m, monthDays(m, y))) m++;
    return { y: y, m: m, d: abs - toAbs(y, m, 1) + 1 };
  }
  // תאריך לועזי (שנה, חודש 1-12, יום) ↔ מספר יום
  function gAbs(y, m, d) { return Math.round(Date.UTC(y, m - 1, d) / 864e5) + 719163; }
  function absG(abs) { var t = new Date((abs - 719163) * 864e5); return { y: t.getUTCFullYear(), m: t.getUTCMonth() + 1, d: t.getUTCDate() }; }
  function dow(abs) { return ((abs % 7) + 7) % 7; }   // 0 = ראשון … 6 = שבת
  // תאריך לועזי של הפטירה → עברי. אחרי השקיעה – כבר היום העברי הבא
  function fromGreg(y, m, d, afterSunset) { return fromAbs(gAbs(y, m, d) + (afterSunset ? 1 : 0)); }

  // היארצייט של פטירה {y,m,d} בשנה העברית hy (לפי הכללים המקובלים, כמו ב-Hebcal).
  // adar: '1' = פטירה באדר של שנה פשוטה נזכרת בשנה מעוברת באדר א (מנהג אשכנז), '2' = באדר ב (מנהג ספרד)
  function yahrzeit(death, hy, adar) {
    var m = death.m, d = death.d;
    if (hy <= death.y) return null;
    if (m === 8 && d === 30 && !longCheshvan(death.y + 1)) return toAbs(hy, 9, 1) - 1;   // ל' חשון ובשנה הראשונה אחרי לא היה – יום אחרון של חשון
    if (m === 9 && d === 30 && shortKislev(death.y + 1)) return toAbs(hy, 10, 1) - 1;   // ל' כסלו – כנ"ל
    if (m === 13) m = months(hy);                       // אדר ב – בשנה פשוטה: אדר
    else if (m === 12 && leap(death.y)) {               // אדר א
      if (!leap(hy) && d === 30) return toAbs(hy, 11, 30);   // ל' אדר א בשנה פשוטה – ל' שבט
    } else if (m === 12 && !leap(death.y) && leap(hy) && adar === '2') m = 13;   // אדר של שנה פשוטה, בשנה מעוברת
    return toAbs(hy, m, d);
  }
  // היארצייט שנופל בטווח [from, to] (מספרי ימים). תאריך קבוע ידני {m,d} גובר על החישוב
  function yahrzeitIn(p, from, to, adar) {
    var y0 = fromAbs(from).y, out = [];
    for (var hy = y0 - 1; hy <= y0 + 1; hy++) {
      var a = p.fix ? toAbs(hy, p.fix.m === 13 && !leap(hy) ? 12 : p.fix.m, p.fix.d) : yahrzeit(p, hy, adar);
      if (a !== null && a >= from && a <= to && (!p.fix || hy > p.y)) out.push(a);
    }
    return out[0] === undefined ? null : out[0];
  }

  // ---------- גימטריה ----------
  var ONES = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'], TENS = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'], HUND = ['', 'ק', 'ר', 'ש', 'ת'];
  function gem(n, marks) {   // 18 → י״ח, 5752 → תשנ״ב
    n = n % 1000; var s = '';
    while (n >= 400) { s += 'ת'; n -= 400; }
    s += HUND[Math.floor(n / 100)]; n %= 100;
    if (n === 15) s += 'טו'; else if (n === 16) s += 'טז'; else s += TENS[Math.floor(n / 10)] + ONES[n % 10];
    if (marks === false) return s;
    return s.length === 1 ? s + '׳' : s.slice(0, -1) + '״' + s.slice(-1);
  }
  var VAL = {}; ONES.forEach(function (c, i) { if (c) VAL[c] = i; }); TENS.forEach(function (c, i) { if (c) VAL[c] = i * 10; }); HUND.forEach(function (c, i) { if (c) VAL[c] = i * 100; });
  VAL['ך'] = 20; VAL['ם'] = 40; VAL['ן'] = 50; VAL['ף'] = 80; VAL['ץ'] = 90;
  function ungem(s) {   // "י״ח" / "18" → 18
    s = String(s || '').replace(/[׳״'"\s]/g, '');
    if (/^\d+$/.test(s)) return +s;
    var n = 0; for (var i = 0; i < s.length; i++) { if (VAL[s[i]] === undefined) return NaN; n += VAL[s[i]]; }
    return n || NaN;
  }
  function yearOf(s) {   // "תשנ״ב" / "ה׳תשנ״ב" / "5752" → 5752
    s = String(s || '').trim();
    if (/^\d{4}$/.test(s)) return +s;
    s = s.replace(/^ה['׳]/, '');
    var n = ungem(s); return isNaN(n) ? NaN : (n < 1000 ? 5000 + n : n);
  }
  var MONTH = { 1: 'ניסן', 2: 'אייר', 3: 'סיון', 4: 'תמוז', 5: 'אב', 6: 'אלול', 7: 'תשרי', 8: 'חשון', 9: 'כסלו', 10: 'טבת', 11: 'שבט', 12: 'אדר', 13: 'אדר ב׳' };
  function monthName(m, y) { return m === 12 && y && leap(y) ? 'אדר א׳' : MONTH[m]; }
  function monthOf(s) {   // שם חודש בכתיב חופשי → מספר
    s = String(s || '').replace(/[׳'"\s-]/g, '').replace(/^ב/, function (x) { return /^ב(ניסן|אייר|סיון|סיוון|תמוז|אב|אלול|תשרי|חשון|חשוון|מרחשון|מרחשוון|כסלו|כסליו|טבת|שבט|אדר)/.test(s) ? '' : x; });
    var t = { 'ניסן': 1, 'אייר': 2, 'איר': 2, 'סיון': 3, 'סיוון': 3, 'תמוז': 4, 'אב': 5, 'מנחםאב': 5, 'אלול': 6, 'תשרי': 7, 'חשון': 8, 'חשוון': 8, 'מרחשון': 8, 'מרחשוון': 8,
      'כסלו': 9, 'כסליו': 9, 'טבת': 10, 'שבט': 11, 'אדר': 12, 'אדרא': 12, 'אדרראשון': 12, 'אדרב': 13, 'אדרשני': 13, 'ואדר': 13 };
    return t[s] || NaN;
  }
  function fmt(h, withYear) { return gem(h.d) + ' ' + monthName(h.m, h.y) + (withYear ? ' ' + gem(h.y) : ''); }

  // ---------- שקיעה (NOAA), בדקות מחצות לפי שעון מקומי ----------
  function sunset(gy, gm, gd, lat, lon, tzOffsetMin) {
    var rad = Math.PI / 180, n = gAbs(gy, gm, gd) - gAbs(2000, 1, 1) + 0.5 - lon / 360;
    var L = (280.46 + 0.9856474 * n) % 360, g = (357.528 + 0.9856003 * n) * rad;
    var lam = (L + 1.915 * Math.sin(g) + 0.02 * Math.sin(2 * g)) * rad, eps = (23.439 - 0.0000004 * n) * rad;
    var dec = Math.asin(Math.sin(eps) * Math.sin(lam));
    var ra = Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam)) / rad;
    var eqt = (L - ((ra + 360) % 360)); if (eqt > 180) eqt -= 360; if (eqt < -180) eqt += 360;
    var cosH = (Math.sin(-0.833 * rad) - Math.sin(lat * rad) * Math.sin(dec)) / (Math.cos(lat * rad) * Math.cos(dec));
    if (cosH < -1 || cosH > 1) return 18 * 60;
    var H = Math.acos(cosH) / rad;
    return 720 - 4 * lon - 4 * eqt + 4 * H + tzOffsetMin;
  }

  G.HEB = { toAbs: toAbs, fromAbs: fromAbs, gAbs: gAbs, absG: absG, dow: dow, fromGreg: fromGreg, leap: leap, months: months, monthDays: monthDays,
    yahrzeit: yahrzeit, yahrzeitIn: yahrzeitIn, gem: gem, ungem: ungem, yearOf: yearOf, monthOf: monthOf, monthName: monthName, fmt: fmt, sunset: sunset };
})(typeof window !== 'undefined' ? window : globalThis);
