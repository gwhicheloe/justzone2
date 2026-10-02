/* Justzone2 Interval Builder — the web version of the app's builder.
 *
 * The session model is a faithful port of the app's IntervalSession
 * (justzone2/Models/IntervalSession.swift): same segments, same rules
 * (no recovery after the last interval; warm-up and cool-down ridden at the
 * recovery power), same default name, same option lists and limits, and the
 * same weighted average power calculation. Keep the two in step.
 *
 * The page is a simple demo: one session, nothing saved.
 *
 * The model functions are pure (no DOM) so they can be tested on their own:
 *   node -e "const m=require('./js/intervals.js'); ..."
 */
(function (root) {
  "use strict";

  // ── Model (mirrors IntervalSession.swift) ──────────────────────────────

  var WORK_DURATIONS = [15, 20, 30, 40, 45, 60, 90, 120, 150, 180, 240, 300, 360, 420, 480, 600, 720, 900, 1200, 1500, 1800];
  var REST_DURATIONS = [10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480, 600];
  var EASY_DURATIONS = [0, 180, 300, 420, 600, 720, 900, 1200, 1800];
  var COUNT_MIN = 1, COUNT_MAX = 30, POWER_MIN = 30, POWER_MAX = 1500;

  function newTemplate() {
    return {
      id: uid(), customName: "",
      intervalCount: 5, workDuration: 4 * 60, workPower: 220,
      restDuration: 3 * 60, restPower: 120,
      warmUpDuration: 10 * 60, coolDownDuration: 5 * 60
    };
  }

  function uid() {
    try { if (root.crypto && root.crypto.randomUUID) return root.crypto.randomUUID(); } catch (e) {}
    return "s" + Date.now().toString(36) + Math.random().toString(36).slice(2);
  }

  /** "4 min", "90 s" → "1 min 30 s", "1 h 5 min". */
  function formatDuration(d) {
    var s = Math.round(d), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    if (h > 0) return m > 0 ? h + " h " + m + " min" : h + " h";
    if (m > 0) return sec > 0 ? m + " min " + sec + " s" : m + " min";
    return sec + " s";
  }

  /** Countdown clock, as the app shows it: "04:32" or "1:02:05". */
  function formatTime(t) {
    var s = Math.max(0, Math.floor(t)), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    var pad = function (n) { return (n < 10 ? "0" : "") + n; };
    return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : pad(m) + ":" + pad(sec);
  }

  function defaultName(x) {
    return x.intervalCount + " × " + formatDuration(x.workDuration) + " @ " + x.workPower + " W";
  }

  function name(x) {
    var custom = (x.customName || "").trim();
    return custom || defaultName(x);
  }

  function recoverySummary(x) {
    return formatDuration(x.restDuration) + " recovery @ " + x.restPower + " W";
  }

  function segments(x) {
    var out = [], t = 0;
    function add(kind, duration, power, number) {
      if (!(duration > 0)) return;
      out.push({ kind: kind, start: t, duration: duration, power: power, number: number, end: t + duration });
      t += duration;
    }
    add("warmUp", x.warmUpDuration, x.restPower, 0);
    var n = Math.max(x.intervalCount, 1);
    for (var i = 1; i <= n; i++) {
      add("work", x.workDuration, x.workPower, i);
      // No recovery after the last interval — the cool-down follows.
      if (i < x.intervalCount) add("rest", x.restDuration, x.restPower, i);
    }
    add("coolDown", x.coolDownDuration, x.restPower, 0);
    return out;
  }

  function totalDuration(x) {
    return x.warmUpDuration + x.coolDownDuration +
      x.intervalCount * x.workDuration + Math.max(x.intervalCount - 1, 0) * x.restDuration;
  }

  /** Plain time-weighted average power. */
  function averagePower(x) {
    var segs = segments(x), sum = 0, secs = 0;
    segs.forEach(function (s) { sum += s.power * s.duration; secs += s.duration; });
    return secs ? Math.round(sum / secs) : 0;
  }

  /** Weighted average power: 1 s series → 30 s rolling average → ^4 → mean → 4th root. */
  function weightedAveragePower(x) {
    var watts = [];
    segments(x).forEach(function (s) {
      for (var i = 0, n = Math.max(Math.round(s.duration), 0); i < n; i++) watts.push(s.power);
    });
    if (!watts.length) return 0;
    var window = 30;
    if (watts.length < window) {
      return Math.round(watts.reduce(function (a, b) { return a + b; }, 0) / watts.length);
    }
    var rolling = 0;
    for (var i = 0; i < window; i++) rolling += watts[i];
    var sumFourth = Math.pow(rolling / window, 4);
    for (i = window; i < watts.length; i++) {
      rolling += watts[i] - watts[i - window];
      sumFourth += Math.pow(rolling / window, 4);
    }
    return Math.round(Math.pow(sumFourth / (watts.length - window + 1), 0.25));
  }

  function segmentAt(x, elapsed) {
    var all = segments(x);
    for (var i = 0; i < all.length; i++) if (elapsed < all[i].end) return all[i];
    return all[all.length - 1] || null;
  }

  function nextWork(x, elapsed) {
    var all = segments(x);
    for (var i = 0; i < all.length; i++) if (all[i].kind === "work" && all[i].start > elapsed) return all[i];
    return null;
  }

  function clampPower(p) { return Math.min(Math.max(Math.round(p) || 0, POWER_MIN), POWER_MAX); }
  function clampCount(n) { return Math.min(Math.max(Math.round(n) || 0, COUNT_MIN), COUNT_MAX); }

  var model = {
    WORK_DURATIONS: WORK_DURATIONS, REST_DURATIONS: REST_DURATIONS, EASY_DURATIONS: EASY_DURATIONS,
    COUNT_MIN: COUNT_MIN, COUNT_MAX: COUNT_MAX, POWER_MIN: POWER_MIN, POWER_MAX: POWER_MAX,
    newTemplate: newTemplate, formatDuration: formatDuration, formatTime: formatTime,
    defaultName: defaultName, name: name, recoverySummary: recoverySummary,
    segments: segments, totalDuration: totalDuration, averagePower: averagePower,
    weightedAveragePower: weightedAveragePower, segmentAt: segmentAt, nextWork: nextWork,
    clampPower: clampPower, clampCount: clampCount
  };

  if (typeof module !== "undefined" && module.exports) { module.exports = model; return; }
  root.JZIntervals = model;

  // ── UI ─────────────────────────────────────────────────────────────────
  // A simple demo of the app's builder: edit one session and watch its shape,
  // total time and weighted average power update. Nothing is saved.

  var WORK = "#E08038";   // the app's Zone 4 colour — work intervals
  var EASY = "#5CA8DB";   // the app's Zone 1 colour — warm-up, recovery, cool-down

  var $ = function (id) { return document.getElementById(id); };
  var session = newTemplate();

  /** Draw a session's shape into an <svg>: bar width = duration, height = power. */
  function drawProfile(svg, x) {
    var w = Math.max(svg.clientWidth || svg.parentNode.clientWidth || 300, 50);
    var h = Math.max(svg.clientHeight || 40, 10);
    var segs = segments(x), total = Math.max(totalDuration(x), 1);
    var maxP = Math.max.apply(null, segs.map(function (s) { return s.power; }).concat([1]));
    var gap = segs.length > 40 ? 0.5 : 1;
    svg.setAttribute("viewBox", "0 0 " + w + " " + h);
    svg.innerHTML = segs.map(function (s) {
      var sx = w * s.start / total, sw = Math.max(w * s.duration / total - gap, 1);
      // Keep easy segments visible even when the work power is far higher.
      var sh = Math.max(h * s.power / maxP, h * 0.12), sy = h - sh, r = Math.min(2, sw / 2);
      return '<path fill="' + (s.kind === "work" ? WORK : EASY) + '" fill-opacity=".95" d="M' + sx + " " + h + "V" + (sy + r) +
        "Q" + sx + " " + sy + " " + (sx + r) + " " + sy + "H" + (sx + sw - r) +
        "Q" + (sx + sw) + " " + sy + " " + (sx + sw) + " " + (sy + r) + "V" + h + 'Z"/>';
    }).join("");
  }

  function fillSelect(sel, options, value) {
    var opts = options.indexOf(value) >= 0 ? options : options.concat([value]).sort(function (a, b) { return a - b; });
    sel.innerHTML = opts.map(function (d) {
      return '<option value="' + d + '"' + (d === value ? " selected" : "") + ">" + (d === 0 ? "None" : formatDuration(d)) + "</option>";
    }).join("");
  }

  function syncForm() {
    $("ib-count").textContent = session.intervalCount;
    $("ib-count-dec").disabled = session.intervalCount <= COUNT_MIN;
    $("ib-count-inc").disabled = session.intervalCount >= COUNT_MAX;
    fillSelect($("ib-work-dur"), WORK_DURATIONS, session.workDuration);
    fillSelect($("ib-rest-dur"), REST_DURATIONS, session.restDuration);
    fillSelect($("ib-warm"), EASY_DURATIONS, session.warmUpDuration);
    fillSelect($("ib-cool"), EASY_DURATIONS, session.coolDownDuration);
    if (document.activeElement !== $("ib-work-pow")) $("ib-work-pow").value = session.workPower;
    if (document.activeElement !== $("ib-rest-pow")) $("ib-rest-pow").value = session.restPower;
    render();
  }

  function render() {
    var dn = defaultName(session);
    $("ib-name").placeholder = dn;
    $("ib-name-foot").textContent = 'Leave blank to use "' + dn + '".';
    $("ib-title").textContent = name(session);
    $("ib-total").textContent = formatDuration(totalDuration(session));
    $("ib-intervals").textContent = session.intervalCount + (session.intervalCount === 1 ? " interval" : " intervals");
    $("ib-wap").textContent = weightedAveragePower(session);
    $("ib-avg").textContent = averagePower(session);
    drawProfile($("ib-profile"), session);
  }

  function bindPower(input, key) {
    input.addEventListener("input", function () {
      var v = parseInt(input.value, 10);
      if (!isNaN(v)) { session[key] = clampPower(v); render(); }
    });
    input.addEventListener("change", function () { session[key] = clampPower(input.value); input.value = session[key]; render(); });
  }

  function step(key, delta) {
    if (key === "intervalCount") session.intervalCount = clampCount(session.intervalCount + delta);
    else session[key] = clampPower(session[key] + delta);
    syncForm();
  }

  function init() {
    if (!$("ib-app")) return;
    $("ib-count-dec").addEventListener("click", function () { step("intervalCount", -1); });
    $("ib-count-inc").addEventListener("click", function () { step("intervalCount", 1); });
    [["ib-work-dec", "workPower", -5], ["ib-work-inc", "workPower", 5], ["ib-rest-dec", "restPower", -5], ["ib-rest-inc", "restPower", 5]]
      .forEach(function (b) { $(b[0]).addEventListener("click", function () { step(b[1], b[2]); }); });
    bindPower($("ib-work-pow"), "workPower");
    bindPower($("ib-rest-pow"), "restPower");
    [["ib-work-dur", "workDuration"], ["ib-rest-dur", "restDuration"], ["ib-warm", "warmUpDuration"], ["ib-cool", "coolDownDuration"]]
      .forEach(function (p) { $(p[0]).addEventListener("change", function () { session[p[1]] = Number(this.value); syncForm(); }); });
    $("ib-name").addEventListener("input", function () { session.customName = this.value; render(); });

    // Presets. The 30/15 is one set of Rønnestad's session: the builder (like
    // the app's) has no sets, so the research's 3 sets × 13 is noted on the page.
    var presets = {
      "ib-preset-3015": { customName: "Rønnestad 30/15s", intervalCount: 13, workDuration: 30, workPower: 300,
                           restDuration: 15, restPower: 150, warmUpDuration: 900, coolDownDuration: 600 },
      "ib-preset-default": {}
    };
    var clearPresets = function () { Object.keys(presets).forEach(function (k) { $(k).classList.remove("on"); }); };
    Object.keys(presets).forEach(function (id) {
      $(id).addEventListener("click", function () {
        session = Object.assign(newTemplate(), presets[id]);
        clearPresets(); $(id).classList.add("on");
        $("ib-preset-note").hidden = id !== "ib-preset-3015";
        syncForm();
        $("ib-name").value = session.customName || "";
      });
    });
    // Any edit means it's no longer exactly the preset.
    $("ib-app").addEventListener("input", clearPresets);
    $("ib-app").addEventListener("change", clearPresets);
    $("ib-app").addEventListener("click", function (e) { if (e.target.closest(".ib-step")) clearPresets(); });

    var resizeTimer;
    root.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () { drawProfile($("ib-profile"), session); }, 100);
    });

    syncForm();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})(this);
