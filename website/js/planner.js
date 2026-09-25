/* Justzone2 training-week planner.
 *
 * Turns "hours per week" (+ whether to include a weekend long ride) into a
 * seven-day plan. The rules follow the site's own evidence review
 * (/blog/zone-2-evidence-review):
 *
 *  - Two hard sessions a week, always: one VO2max session and one threshold
 *    session. "Go hard two or three times a week" — and at low volume the
 *    hard sessions are protected first.
 *  - Everything else is genuinely easy Zone 2, and it is what grows with
 *    hours. Low-intensity share rises with volume because that is what a big
 *    week has to look like to be absorbable.
 *  - The long ride is optional: it is specific preparation for long events
 *    (durability), not a requirement. It only goes in once the week has room
 *    for it on top of the two hard sessions.
 *  - Hard days are never back to back, and at least one full rest day stays.
 *
 * buildWeek() is pure (no DOM) so the rules can be tested on their own.
 */
(function (root) {
  "use strict";

  var DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  var MIN_HOURS = 3, MAX_HOURS = 15;
  var MIN_Z2 = 0.75;          // shortest Zone 2 ride worth scheduling (45 min)
  var LONG_MIN = 1.5, LONG_MAX = 4.5, LONG_SHARE = 0.3;
  var HARD_MAX = 2;           // a hard day can be padded with easy riding up to this

  function q(h) { return Math.round(h * 4) / 4; }   // nearest 15 minutes

  // The two hard sessions scale a little with the week: more reps, a longer
  // warm-up. Work = minutes actually spent at intensity. The steps sit at 6 h
  // and 10 h, the review's own low- and high-volume thresholds.
  function hardSessions(H) {
    if (H < 6) return {
      hours: 1,
      vo2: { reps: 4, work: 16, spec: "4 × 4 min hard, 3 min easy between" },
      thr: { reps: 3, work: 24, spec: "3 × 8 min at threshold, 4 min easy between" }
    };
    if (H < 10) return {
      hours: 1.25,
      vo2: { reps: 5, work: 20, spec: "5 × 4 min hard, 3 min easy between" },
      thr: { reps: 3, work: 30, spec: "3 × 10 min at threshold, 5 min easy between" }
    };
    return {
      hours: 1.5,
      vo2: { reps: 6, work: 24, spec: "6 × 4 min hard, 3 min easy between" },
      thr: { reps: 2, work: 40, spec: "2 × 20 min at threshold, 5 min easy between" }
    };
  }

  // Share Zone 2 hours across the free days, weighted, respecting caps.
  function fill(total, days, weights, caps) {
    var alloc = {}, active = days.slice(), rem = total;
    days.forEach(function (d) { alloc[d] = 0; });
    for (var guard = 0; rem > 1e-9 && active.length && guard < 20; guard++) {
      var wsum = active.reduce(function (s, d) { return s + weights[d]; }, 0);
      var capped = [], used = 0;
      active.forEach(function (d) {
        var share = rem * weights[d] / wsum, room = caps[d] - alloc[d];
        if (share >= room) { alloc[d] += room; used += room; capped.push(d); }
      });
      if (!capped.length) {
        active.forEach(function (d) { alloc[d] += rem * weights[d] / wsum; });
        rem = 0;
      } else {
        rem -= used;
        active = active.filter(function (d) { return capped.indexOf(d) < 0; });
      }
    }
    return { alloc: alloc, left: Math.max(0, rem) };
  }

  function buildWeek(hoursIn, wantLong) {
    var H = q(Math.min(MAX_HOURS, Math.max(MIN_HOURS, hoursIn)));
    var hs = hardSessions(H);
    var notes = [];

    // Long ride: roughly 30% of the week, 1.5–4.5 h, only if it fits on top
    // of the two hard sessions.
    var longH = 0, longDropped = false;
    if (wantLong) {
      longH = q(Math.min(LONG_MAX, Math.max(LONG_MIN, H * LONG_SHARE)));
      if (H - 2 * hs.hours < longH) { longH = 0; longDropped = true; }
    }

    var plan = DAYS.map(function (d) { return { day: d, type: "rest", hours: 0 }; });
    plan[1] = { day: DAYS[1], type: "vo2", hours: hs.hours, spec: hs.vo2.spec, work: hs.vo2.work };
    plan[3] = { day: DAYS[3], type: "threshold", hours: hs.hours, spec: hs.thr.spec, work: hs.thr.work };
    if (longH) plan[5] = { day: DAYS[5], type: "long", hours: longH };

    // Zone 2 days, most-wanted first. Monday is the first to become a rest
    // day (after the weekend); Friday stays short before a long Saturday.
    var pref = longH ? [2, 6, 4, 0] : [5, 2, 6, 4, 0];
    var weights = { 0: 0.8, 2: 1.2, 4: 0.8, 5: 1.4, 6: 1.0 };
    var caps = { 0: 1.5, 2: 2.5, 4: longH ? 1.5 : 2, 5: 4, 6: 3 };
    var restDays = H <= 6 ? 2 : 1;
    var R = H - 2 * hs.hours - longH;

    // Too little left for a worthwhile ride: fold it into the long ride (or
    // onto the hard days) rather than schedule a token 30-minute spin.
    if (R > 0 && R < MIN_Z2) {
      if (longH) { var room = LONG_MAX - longH, add = Math.min(room, R); longH += add; plan[5].hours = longH; R -= add; }
    }
    var n = Math.min(pref.length - restDays, Math.floor(R / MIN_Z2 + 1e-9));
    var res;
    for (; n >= 1; n--) {                       // fewest days that keep every ride ≥ 45 min
      res = fill(R, pref.slice(0, n), weights, caps);
      var ok = pref.slice(0, n).every(function (d) { return res.alloc[d] >= MIN_Z2 - 1e-9 || n === 1; });
      if (ok) break;
    }
    var z2days = n >= 1 ? pref.slice(0, n) : [];
    // Zone 2 that didn't fit on free days (or a sub-45-min remainder with no
    // long ride to absorb it) goes on the hard days as easy riding afterwards.
    var extra = n >= 1 ? res.left : R;

    // Round to 15 minutes, then correct any rounding drift on the biggest day.
    z2days.forEach(function (d) { plan[d] = { day: DAYS[d], type: "z2", hours: q(res.alloc[d]) }; });
    var pad = q(extra / 2);
    if (pad > 0) {
      [1, 3].forEach(function (d) {
        var add = Math.min(pad, HARD_MAX - plan[d].hours);
        plan[d].hours += add; plan[d].easyAfter = add;
      });
    }
    var drift = q(H - plan.reduce(function (s, p) { return s + p.hours; }, 0));
    if (drift !== 0) {
      var target = z2days.length
        ? z2days.reduce(function (a, d) { return plan[d].hours > plan[a].hours ? d : a; }, z2days[0])
        : (longH ? 5 : 1);
      plan[target].hours = q(plan[target].hours + drift);
    }

    // Time at intensity vs everything easy (warm-ups, recoveries and
    // cool-downs inside the hard sessions are easy riding too).
    var total = plan.reduce(function (s, p) { return s + p.hours; }, 0) * 60;
    var vo2Min = hs.vo2.work, thrMin = hs.thr.work;
    var easyMin = total - vo2Min - thrMin;

    if (longDropped) notes.push({ kind: "long", text:
      "Not included at " + fmtH(H) + ": it needs about " + fmtH(LONG_MIN + 2 * hs.hours) +
      " a week, and your two hard sessions come first." });
    if (H < 6) notes.push({ kind: "volume", text:
      "At " + fmtH(H) + " a week, your two hard sessions do most of the work, so protect them. " +
      "Zone 2 fills the gaps and helps you recover between them." });
    else if (H >= 10) notes.push({ kind: "volume", text:
      "At " + fmtH(H) + " a week, most of your riding is easy because it has to be — this much " +
      "hard riding couldn't be absorbed. The easy volume is what builds the base." });
    else notes.push({ kind: "volume", text:
      "Two hard sessions stay fixed; every extra hour you add goes into Zone 2. " +
      "Keep the easy days genuinely easy so the hard days can be hard." });

    return {
      hours: H,
      long: longH > 0,
      longDropped: longDropped,
      days: plan,
      minutes: { easy: easyMin, threshold: thrMin, vo2: vo2Min, total: total },
      rideDays: plan.filter(function (p) { return p.type !== "rest"; }).length,
      notes: notes
    };
  }

  function fmtH(h) {
    var hh = Math.floor(h + 1e-9), mm = Math.round((h - hh) * 60);
    if (!hh) return mm + " min";
    return mm ? hh + " h " + mm + " min" : hh + (hh === 1 ? " hour" : " hours");
  }

  var api = { buildWeek: buildWeek, fmtH: fmtH, MIN_HOURS: MIN_HOURS, MAX_HOURS: MAX_HOURS, DAYS: DAYS };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.JZPlanner = api;
})(this);
