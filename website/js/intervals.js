/* Justzone2 Interval Builder — the web version of the app's builder.
 *
 * The session model is a faithful port of the app's IntervalSession
 * (justzone2/Models/IntervalSession.swift): same segments, same rules
 * (no recovery after the last interval; warm-up and cool-down ridden at the
 * recovery power), same default name, same option lists and limits, and the
 * same weighted average power calculation. Keep the two in step.
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

  var WORK = "#E08038";   // the app's Zone 4 colour — work intervals
  var EASY = "#5CA8DB";   // the app's Zone 1 colour — warm-up, recovery, cool-down
  var STORE_KEY = "jz.intervalSessions";
  var PREVIEW_SPEED = 30; // the ride preview runs 30× real time

  var $ = function (id) { return document.getElementById(id); };
  var session = newTemplate();
  var saved = loadSaved();

  function loadSaved() {
    try { var raw = root.localStorage.getItem(STORE_KEY); return raw ? JSON.parse(raw) : []; }
    catch (e) { return []; }
  }
  function persist() {
    try { root.localStorage.setItem(STORE_KEY, JSON.stringify(saved)); } catch (e) {}
  }

  /** Draw a session's shape into an <svg>: bar width = duration, height = power. */
  function drawProfile(svg, x, elapsed) {
    var w = Math.max(svg.clientWidth || svg.parentNode.clientWidth || 300, 50);
    var h = Math.max(svg.clientHeight || 40, 10);
    var segs = segments(x), total = Math.max(totalDuration(x), 1);
    var maxP = Math.max.apply(null, segs.map(function (s) { return s.power; }).concat([1]));
    var gap = segs.length > 40 ? 0.5 : 1;
    var parts = [];
    segs.forEach(function (s) {
      var sx = w * s.start / total, sw = Math.max(w * s.duration / total - gap, 1);
      // Keep easy segments visible even when the work power is far higher.
      var sh = Math.max(h * s.power / maxP, h * 0.12), sy = h - sh;
      var color = s.kind === "work" ? WORK : EASY;
      var r = Math.min(2, sw / 2);
      var path = function (px, pw, op) {
        return '<path fill="' + color + '" fill-opacity="' + op + '" d="M' + px + ' ' + h + 'V' + (sy + r) +
          'Q' + px + ' ' + sy + ' ' + (px + r) + ' ' + sy + 'H' + (px + pw - r) +
          'Q' + (px + pw) + ' ' + sy + ' ' + (px + pw) + ' ' + (sy + r) + 'V' + h + 'Z"/>';
      };
      if (elapsed == null || elapsed >= s.end) {
        parts.push(path(sx, sw, 0.95));
      } else if (elapsed < s.start) {
        parts.push(path(sx, sw, 0.35));
      } else {
        // Current segment: ridden part solid, the rest still to come.
        parts.push(path(sx, sw, 0.35));
        var doneW = sw * (elapsed - s.start) / s.duration;
        if (doneW > 0.5) parts.push('<rect fill="' + color + '" fill-opacity=".95" x="' + sx + '" y="' + (sy + r) +
          '" width="' + doneW + '" height="' + (sh - r) + '"/>');
      }
    });
    if (elapsed != null) {
      var mx = w * Math.min(elapsed / total, 1);
      parts.push('<rect x="' + (mx - 1.5) + '" y="0" width="3" height="' + h + '" rx="1.5" fill="#fff"/>');
    }
    svg.setAttribute("viewBox", "0 0 " + w + " " + h);
    svg.innerHTML = parts.join("");
  }

  // ── Editor ──

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
    $("ib-name").value = session.customName || "";
    render();
  }

  function render() {
    var dn = defaultName(session);
    $("ib-name").placeholder = dn;
    $("ib-name-foot").textContent = 'Leave blank to use "' + dn + '".';
    $("ib-total").textContent = formatDuration(totalDuration(session));
    $("ib-intervals").textContent = session.intervalCount + " intervals";
    $("ib-wap").textContent = weightedAveragePower(session);
    $("ib-avg").textContent = averagePower(session);
    updateSaveLabels();
    drawProfile($("ib-profile"), session, null);
    resetPreview();
  }

  function updateSaveLabels() {
    var isSaved = saved.some(function (s) { return s.id === session.id; });
    $("ib-mode").textContent = isSaved ? "Edit Session" : "New Session";
    $("ib-save").textContent = isSaved ? "Save changes" : "Save session";
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

  // ── Saved sessions ──

  function renderSaved() {
    var list = $("ib-saved");
    if (!saved.length) {
      list.innerHTML = '<p class="ib-empty">No saved sessions yet. Saved sessions stay in this browser.</p>';
      return;
    }
    list.innerHTML = saved.map(function (s, i) {
      return '<div class="ib-row' + (s.id === session.id ? " on" : "") + '">' +
        '<button type="button" class="ib-row-main" data-open="' + i + '">' +
          '<span class="ib-row-top"><b>' + esc(name(s)) + '</b><span>' + formatDuration(totalDuration(s)) + "</span></span>" +
          '<svg class="ib-row-prof" aria-hidden="true" data-prof="' + i + '"></svg>' +
          '<span class="ib-row-foot"><span>' + recoverySummary(s) + "</span><span>Weighted avg " + weightedAveragePower(s) + " W</span></span>" +
        "</button>" +
        '<button type="button" class="ib-row-del" data-del="' + i + '" aria-label="Delete ' + esc(name(s)) + '">×</button>' +
        "</div>";
    }).join("");
    saved.forEach(function (s, i) { drawProfile(list.querySelector('[data-prof="' + i + '"]'), s, null); });
  }

  function esc(t) { return String(t).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  // ── Ride preview: the app's in-ride display, sped up ──

  var preview = { t: 0, playing: false, last: 0, raf: 0 };

  function resetPreview() {
    preview.t = 0; setPlaying(false); drawPreview();
  }

  function setPlaying(on) {
    preview.playing = on;
    $("ib-play").textContent = on ? "Pause" : (preview.t > 0 && preview.t < totalDuration(session) ? "Resume" : "Ride preview");
    $("ib-play").setAttribute("aria-pressed", on ? "true" : "false");
    if (on) { preview.last = performance.now(); preview.raf = requestAnimationFrame(tick); }
    else cancelAnimationFrame(preview.raf);
  }

  function tick(now) {
    if (!preview.playing) return;
    preview.t += (now - preview.last) / 1000 * PREVIEW_SPEED;
    preview.last = now;
    var total = totalDuration(session);
    if (preview.t >= total) { preview.t = total; drawPreview(); setPlaying(false); $("ib-play").textContent = "Ride again"; preview.t = 0; return; }
    drawPreview();
    preview.raf = requestAnimationFrame(tick);
  }

  function drawPreview() {
    var t = preview.t, seg = segmentAt(session, t);
    var phase = $("ib-phase"), caption = $("ib-caption"), big = $("ib-big"), next = $("ib-next");
    if (!seg) return;
    var color = seg.kind === "work" ? WORK : EASY;
    var label = { warmUp: "WARM UP", work: "INTERVAL " + seg.number + " OF " + session.intervalCount, rest: "RECOVERY", coolDown: "COOL DOWN" }[seg.kind];
    var upcoming = seg.kind !== "work" ? nextWork(session, t) : null;
    var until = upcoming ? Math.max(upcoming.start - t, 0) : null;
    var bigTime = until != null ? until : Math.max(seg.end - t, 0);
    phase.textContent = label;
    phase.style.color = color;
    phase.style.background = color + "29";
    caption.textContent = upcoming ? "Interval " + upcoming.number + " of " + session.intervalCount + " starts in"
      : seg.kind === "work" ? "Interval ends in" : seg.kind === "coolDown" ? "Cool-down ends in" : "Time left";
    big.textContent = formatTime(bigTime);
    big.style.color = until != null && until <= 10 ? WORK : color;
    big.classList.toggle("pulse", until != null && until <= 3 && preview.playing);
    next.innerHTML = '<span class="ib-watt" style="color:' + color + '">' + seg.power + ' W</span> now' +
      (upcoming ? ' · <span style="color:' + WORK + '">next ' + upcoming.power + " W</span>" : "");
    $("ib-ride").style.setProperty("--tint", color);
    drawProfile($("ib-ride-profile"), session, t);
  }

  // ── Wire up ──

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

    $("ib-save").addEventListener("click", function () {
      var copy = JSON.parse(JSON.stringify(session));
      copy.customName = (copy.customName || "").trim();
      var i = saved.findIndex(function (s) { return s.id === copy.id; });
      if (i >= 0) saved[i] = copy; else saved.push(copy);
      persist(); renderSaved(); updateSaveLabels();
      var b = $("ib-save"); b.classList.add("done"); b.textContent = "Saved ✓";
      // Only restore the button — a full render() would reset a ride preview
      // the rider started in the meantime.
      setTimeout(function () { b.classList.remove("done"); updateSaveLabels(); }, 1200);
    });
    $("ib-new").addEventListener("click", function () { session = newTemplate(); syncForm(); renderSaved(); });

    $("ib-saved").addEventListener("click", function (e) {
      var open = e.target.closest("[data-open]"), del = e.target.closest("[data-del]");
      if (del) {
        var gone = saved.splice(Number(del.dataset.del), 1)[0];
        persist();
        if (gone && gone.id === session.id) session = newTemplate();
        syncForm(); renderSaved();
      } else if (open) {
        session = JSON.parse(JSON.stringify(saved[Number(open.dataset.open)]));
        syncForm(); renderSaved();
        $("ib-app").scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });

    $("ib-play").addEventListener("click", function () { setPlaying(!preview.playing); });
    $("ib-restart").addEventListener("click", function () { preview.t = 0; drawPreview(); if (!preview.playing) setPlaying(true); });
    // Tap the ride profile to jump to that point in the session.
    $("ib-ride-profile").addEventListener("click", function (e) {
      var r = this.getBoundingClientRect();
      preview.t = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * totalDuration(session);
      drawPreview(); if (!preview.playing) $("ib-play").textContent = "Resume";
    });

    var resizeTimer;
    root.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () { drawProfile($("ib-profile"), session, null); renderSaved(); drawPreview(); }, 100);
    });

    syncForm();
    renderSaved();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})(this);
