#!/usr/bin/env python3
"""Draw the book's figures as SVG, from data files kept beside them.

  python3 book/tools/figures.py            draw every figure
  python3 book/tools/figures.py ventoux    draw the ones whose name contains "ventoux"

Rules (see plan.md and style.md): every chart is drawn from numbers in
research.md, with the source in the caption; nothing is copied from a paper.
Figures must read in black and white, because the paperback prints in black
ink: greys only, and nothing that depends on colour to be understood.

House style: 680 units wide, IBM Plex Sans (the book's sans; SIL Open Font
License, so it may be embedded in the printed book), 2 px data lines, hairline
grey axes, labels placed on the chart instead of in a legend. The paperback
prints a figure 4.6 in (331 pt) wide, so one unit is about 0.49 pt: text is
15.5 units (7.5 pt) at the smallest, 16.5 for labels and 18 for titles.
"""
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = os.path.dirname(HERE)
INK, MID, FAINT, BAND = "#1a1a1a", "#555555", "#bdbdbd", "#e6e6e6"
FONT = 'font-family="IBM Plex Sans, Helvetica, Arial, sans-serif"'


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
            f'role="img" aria-label="{title}">\n<rect width="{w}" height="{h}" fill="#ffffff"/>\n'
            + "\n".join(body) + "\n</svg>\n")


def text(x, y, s, size=16.5, fill=INK, anchor="start", weight="400", style=""):
    return (f'<text x="{x:.1f}" y="{y:.1f}" {FONT} font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" font-weight="{weight}" {style}>{s}</text>')


def para(x, y, s, size=15.5, fill=MID, width=620, weight="400", anchor="start"):
    """Text wrapped to a width (estimated from the font size). Returns (elements, baseline of the next line)."""
    per = max(8, int(width / (size * 0.47)))
    rows, cur = [], ""
    for w in s.split():
        if cur and len(cur) + 1 + len(w) > per:
            rows.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    rows.append(cur)
    lh = round(size * 1.25, 1)
    return [text(x, y + i * lh, r, size, fill, anchor, weight) for i, r in enumerate(rows)], y + len(rows) * lh


def head(title, sub, x=30, width=620):
    """A chart's title, which states its point, and the line or two under it. Returns (elements, y below them)."""
    t, y = para(x, 30, title, 18, INK, width, "600")
    s, y = para(x, y + 1, sub, 15.5, MID, width)
    return t + s, y - 4


def ventoux():
    """Forest plot: advantage to the EPO group on each measure in Heuberger 2017."""
    d = os.path.join(BOOK, "chapters", "doping", "figures")
    rows = list(csv.DictReader(l for l in open(os.path.join(d, "ventoux.csv"), encoding="utf-8") if not l.startswith("#")))
    W, left, right, top, rh = 680, 270, 520, 92, 52
    H = top + rh * len(rows) + 70
    lo, hi = -12.0, 10.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    b = []
    # reference band: the 3-5% gain described to the 2015 commission
    b.append(f'<rect x="{X(3):.1f}" y="{top - 12}" width="{X(5) - X(3):.1f}" height="{rh * len(rows) + 8}" fill="{BAND}"/>')
    b.append(text((X(3) + X(5)) / 2, top - 44, "Gain riders described", 15.5, MID, "middle"))
    b.append(text((X(3) + X(5)) / 2, top - 24, "for small doses: 3 to 5%", 15.5, MID, "middle"))
    base = top + rh * len(rows)
    for v in range(-12, 11, 4):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 12}" x2="{X(v):.1f}" y2="{base}" stroke="{FAINT}" stroke-width="{1 if v else 0}"/>')
        b.append(text(X(v), base + 22, f"{v:+d}%".replace("-", "−") if v else "0", 15.5, MID, "middle"))
    b.append(f'<line x1="{X(0):.1f}" y1="{top - 12}" x2="{X(0):.1f}" y2="{base}" stroke="{INK}" stroke-width="1"/>')
    b.append(text(X(0) - 8, base + 48, "← placebo better", 15.5, MID, "end"))
    b.append(text(X(0) + 8, base + 48, "EPO better →", 15.5, MID, "start"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 4
        est, a, c = float(r["estimate"]), float(r["low"]), float(r["high"])
        b.append(text(left - 16, y - 4, r["measure"], 16.5, INK, "end", "600"))
        b.append(text(left - 16, y + 15, r["setting"], 15.5, MID, "end"))
        b.append(f'<line x1="{X(a):.1f}" y1="{y:.1f}" x2="{X(c):.1f}" y2="{y:.1f}" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
        b.append(f'<circle cx="{X(est):.1f}" cy="{y:.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        b.append(text(right + 16, y - 4, f"{est:+.1f}%".replace("-", "−"), 16.5, INK, "start", "600"))
        b.append(text(right + 16, y + 15, f"({a:+.1f} to {c:+.1f})".replace("-", "−"), 15.5, MID, "start"))
    out = os.path.join(d, "ventoux.svg")
    open(out, "w", encoding="utf-8").write(svg(W, H, b, "Advantage to the EPO group on five measures, with 95% confidence intervals"))
    return out


def epo_loop():
    """Diagram: the feedback loop that controls red cell production, and where the drug enters it."""
    d = os.path.join(BOOK, "chapters", "doping", "figures")
    W = 680
    b = ['<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker>'
         '<marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{MID}"/></marker></defs>']

    def box(x, y, w, h, title, lines, fill="#ffffff"):
        o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{INK}" stroke-width="1.5"/>',
             text(x + w / 2, y + 27, title, 18, INK, "middle", "600")]
        for i, l in enumerate(lines):
            o.append(text(x + w / 2, y + 51 + 19 * i, l, 15.5, MID, "middle"))
        return o

    bw, bh = 250, 92
    kx, ky = 20, 72          # kidney, top left
    ex, ey = 410, 72         # EPO in blood, top right
    mx, my = 410, 300        # marrow, bottom right
    rx_, ry = 20, 300        # red cells, bottom left
    b += box(kx, ky, bw, bh, "Kidney", ["senses how much oxygen", "the blood is delivering"])
    b += box(ex, ey, bw, bh, "EPO in the blood", ["the hormone the kidney", "releases when oxygen is low"])
    b += box(mx, my, bw, bh, "Bone marrow", ["more red cell precursors", "survive and mature"])
    b += box(rx_, ry, bw, bh, "Red cells", ["more haemoglobin,", "more oxygen carried"])

    def arrow(x1, y1, x2, y2, col=INK, mk="ah", dash=""):
        return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{col}" stroke-width="2" marker-end="url(#{mk})" {dash}/>'

    gx = (kx + bw + ex) / 2
    b.append(arrow(kx + bw + 6, ky + bh / 2 + 14, ex - 8, ky + bh / 2 + 14))
    b.append(text(gx, ky + bh / 2 - 18, "low oxygen:", 15.5, INK, "middle"))
    b.append(text(gx, ky + bh / 2 + 1, "makes more", 15.5, INK, "middle"))
    b.append(arrow(ex + bw / 2, ey + bh + 6, mx + bw / 2, my - 8))
    b.append(text(ex + bw / 2 + 12, (ey + bh + my) / 2 + 5, "signal", 15.5, INK, "start"))
    b.append(arrow(mx - 6, my + bh / 2 + 14, rx_ + bw + 8, ry + bh / 2 + 14))
    b.append(text(gx, my + bh / 2 - 18, "over days", 15.5, INK, "middle"))
    b.append(text(gx, my + bh / 2 + 1, "to weeks", 15.5, INK, "middle"))
    b.append(arrow(rx_ + bw / 2, ry - 6, kx + bw / 2, ky + bh + 8))
    b.append(text(kx + bw / 2 + 12, (ky + bh + ry) / 2 - 5, "more oxygen reaches", 15.5, INK, "start"))
    b.append(text(kx + bw / 2 + 12, (ky + bh + ry) / 2 + 14, "the kidney: makes less", 15.5, INK, "start"))
    # outside inputs, drawn in grey with dashed arrows
    dash = 'stroke-dasharray="5 4"'
    b.append(text(kx + bw / 2, 24, "Altitude, blood loss, anaemia", 15.5, MID, "middle", "400", 'font-style="italic"'))
    b.append(arrow(kx + bw / 2, 32, kx + bw / 2, ky - 8, MID, "ahg", dash))
    b.append(text(ex + bw / 2, 24, "Injected EPO: bypasses the sensor", 15.5, MID, "middle", "400", 'font-style="italic"'))
    b.append(arrow(ex + bw / 2, 32, ex + bw / 2, ey - 8, MID, "ahg", dash))
    note, y = para(W / 2, my + bh + 34, "Solid arrows: the body's own loop. Dashed arrows: what can push it from outside.", 15.5, MID, 640, anchor="middle")
    b += note
    out = os.path.join(d, "epo-loop.svg")
    open(out, "w", encoding="utf-8").write(svg(W, round(y - 6), b, "The feedback loop controlling red cell production, and where injected EPO enters it"))
    return out


def _rows(chapter, name):
    path = os.path.join(BOOK, "chapters", chapter, "figures", name)
    return list(csv.DictReader(l for l in open(path, encoding="utf-8") if not l.startswith("#")))


def _save(chapter, name, w, h, body, title):
    out = os.path.join(BOOK, "chapters", chapter, "figures", name)
    open(out, "w", encoding="utf-8").write(svg(w, h, body, title))
    return out


def oxygen_route():
    """Diagram: oxygen's route from air to muscle, with the three factors of the Joyner and Coyle model."""
    W = 680
    b = ['<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker></defs>']
    steps = [("Lungs", ["oxygen crosses", "into the blood"]), ("Blood", ["carried by", "haemoglobin"]),
             ("Heart", ["pumps it out:", "cardiac output"]), ("Capillaries", ["deliver it to", "each fibre"]),
             ("Mitochondria", ["use it to", "make ATP"])]
    bw, bh, gap, x0, y0 = 122, 88, 15, 4, 60
    for i, (name, lines) in enumerate(steps):
        x = x0 + i * (bw + gap)
        b.append(f'<rect x="{x}" y="{y0}" width="{bw}" height="{bh}" rx="8" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>')
        b.append(text(x + bw / 2, y0 + 26, name, 16.5, INK, "middle", "600"))
        for k, l in enumerate(lines):
            b.append(text(x + bw / 2, y0 + 50 + 19 * k, l, 15.5, MID, "middle"))
        if i < len(steps) - 1:
            b.append(f'<line x1="{x + bw + 2}" y1="{y0 + bh / 2}" x2="{x + bw + gap - 3}" y2="{y0 + bh / 2}" stroke="{INK}" stroke-width="2" marker-end="url(#ah)"/>')
    b.append(text(x0 + 4, 30, "Air", 16.5, MID, "start", "400", 'font-style="italic"'))
    b.append(f'<line x1="{x0 + 36}" y1="26" x2="{x0 + bw / 2}" y2="{y0 - 8}" stroke="{MID}" stroke-width="1.5" marker-end="url(#ah)"/>')

    def brace(i0, i1, label, subs, y):
        xa, xb = x0 + i0 * (bw + gap), x0 + i1 * (bw + gap) + bw
        b.append(f'<path d="M{xa},{y} v8 H{xb} v-8" fill="none" stroke="{INK}" stroke-width="1.5"/>')
        b.append(text((xa + xb) / 2, y + 30, label, 16.5, INK, "middle", "600"))
        for k, s in enumerate(subs):
            b.append(text((xa + xb) / 2, y + 50 + 19 * k, s, 15.5, MID, "middle"))

    by = y0 + bh + 14
    brace(0, 2, "Delivery: mostly sets VO₂max", ["how much oxygen reaches", "the muscle each minute"], by)
    brace(3, 4, "The muscle", ["mostly sets the fraction", "of VO₂max you can sustain"], by)
    note, y = para(W / 2, by + 106, "Efficiency is the third factor: how much of the energy released ends up as power at the pedals.", 15.5, MID, 640, anchor="middle")
    b += note
    return _save("limits", "oxygen-route.svg", W, round(y - 6), b, "Oxygen's route from the air to the muscle, and the factors that limit endurance")


def cp_decline():
    """Line chart: critical power and W' as a percentage of fresh, over two hours (Clark 2019a)."""
    rows = _rows("durability", "clark2019a.csv")
    W, H, left, right, top, base = 680, 380, 70, 440, 60, 300
    X = lambda m: left + m / 120 * (right - left)
    Y = lambda p: base - (p - 70) / (110 - 70) * (base - top)
    b = []
    for p in (70, 80, 90, 100, 110):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 100 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 5, f"{p}%", 15.5, MID, "end"))
    for m in (0, 40, 80, 120):
        b.append(text(X(m), base + 26, "fresh" if m == 0 else f"{m} min", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 54, "Time ridden at 164 W before the test", 15.5, MID, "middle"))
    b.append(text(14, top - 28, "Per cent of the fresh value", 15.5, MID, "start"))
    cp0, w0 = float(rows[0]["cp_w"]), float(rows[0]["wprime_kj"])
    cp = [(float(r["minutes"]), float(r["cp_w"]) / cp0 * 100) for r in rows]
    wp = [(float(r["minutes"]), float(r["wprime_kj"]) / w0 * 100) for r in rows]
    pts = lambda s: " ".join(f"{X(m):.1f},{Y(p):.1f}" for m, p in s)
    b.append(f'<polyline points="{pts(wp)}" fill="none" stroke="{MID}" stroke-width="2" stroke-dasharray="6 4" stroke-linejoin="round"/>')
    b.append(f'<polyline points="{pts(cp)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for m, p in wp:
        b.append(f'<circle cx="{X(m):.1f}" cy="{Y(p):.1f}" r="4.5" fill="#ffffff" stroke="{MID}" stroke-width="2"/>')
    for m, p in cp:
        b.append(f'<circle cx="{X(m):.1f}" cy="{Y(p):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(right + 16, Y(cp[-1][1]) - 4, "Critical power", 16.5, INK, "start", "600"))
    b.append(text(right + 16, Y(cp[-1][1]) + 15, "236 W, down 9%", 15.5, MID, "start"))
    b.append(text(right + 16, Y(wp[-1][1]) - 4, "W′, the reserve", 16.5, INK, "start", "600"))
    b.append(text(right + 16, Y(wp[-1][1]) + 15, "above it: 13.8 kJ,", 15.5, MID, "start"))
    b.append(text(right + 16, Y(wp[-1][1]) + 34, "down 23%", 15.5, MID, "start"))
    return _save("durability", "cp-decline.svg", W, H, b, "Critical power and W prime as a percentage of their fresh values over two hours of riding")


def carb_dose():
    """Bar chart: fall in critical power after three hours, by carbohydrate intake (Norte 2026)."""
    rows = _rows("durability", "norte2026.csv")
    W, left, right, top, rh = 680, 300, 560, 30, 58
    H = top + rh * len(rows) + 64
    X = lambda v: left + v / 16 * (right - left)
    b, base = [], top + rh * len(rows)
    for v in (0, 4, 8, 12, 16):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{INK if v == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v}%", 15.5, MID, "middle"))
    b.append(text((left + right) / 2 - 20, base + 50, "Fall in critical power after three hours (fresh: 277 W)", 15.5, MID, "middle"))
    for i, r in enumerate(rows):
        y, v = top + rh * i + 10, float(r["fall_pct"])
        b.append(text(left - 14, y + 17, r["condition"], 16.5, INK, "end"))
        b.append(f'<path d="M{X(0):.1f},{y} H{X(v) - 4:.1f} a4,4 0 0 1 4,4 v16 a4,4 0 0 1 -4,4 H{X(0):.1f} z" fill="{MID}"/>')
        b.append(text(X(v) + 10, y + 9, f"{v:.1f}%", 16.5, INK, "start", "600"))
        b.append(text(X(v) + 10, y + 28, f"{r['cp_w']} W left", 15.5, MID, "start"))
    return _save("durability", "carb-dose.svg", W, H, b, "Fall in critical power after three hours of riding, by carbohydrate intake")


def heat_timeline():
    """Line chart: haemoglobin mass during and after five weeks of heat training (Cubel 2024)."""
    rows = _rows("heat-training", "cubel2024.csv")
    W, H, left, right, top, base = 680, 360, 70, 540, 64, 272
    X = lambda wk: left + wk / 7 * (right - left)
    Y = lambda p: base - p / 5 * (base - top)
    b = [f'<rect x="{X(0):.1f}" y="{top}" width="{X(5) - X(0):.1f}" height="{base - top}" fill="{BAND}"/>',
         text((X(0) + X(5)) / 2, top - 30, "Heat sessions: six hours a week", 15.5, MID, "middle"),
         text((X(5) + X(7)) / 2, top - 30, "Stopped", 15.5, MID, "middle"),
         f'<path d="M{X(0):.1f},{top - 18} v6 H{X(5) - 2:.1f} v-6" fill="none" stroke="{MID}" stroke-width="1"/>',
         f'<path d="M{X(5) + 2:.1f},{top - 18} v6 H{X(7):.1f} v-6" fill="none" stroke="{MID}" stroke-width="1"/>']
    for p in range(0, 6):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 5, f"+{p}%" if p else "0", 15.5, MID, "end"))
    for wk in (0, 3, 5, 7):
        b.append(text(X(wk), base + 26, "start" if wk == 0 else f"week {wk}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 56, "Change in total haemoglobin mass", 15.5, MID, "middle"))
    s = [(float(r["week"]), float(r["change_pct"])) for r in rows]
    b.append(f'<polyline points="{" ".join(f"{X(a):.1f},{Y(c):.1f}" for a, c in s)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for a, c in s:
        b.append(f'<circle cx="{X(a):.1f}" cy="{Y(c):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(X(3) - 10, Y(3) - 14, "+3%", 16.5, INK, "end", "600"))
    b.append(text(X(5), Y(4) - 16, "+4%", 16.5, INK, "middle", "600"))
    b.append(text(X(7) + 14, Y(0) - 26, "back to", 15.5, MID, "start"))
    b.append(text(X(7) + 14, Y(0) - 7, "the start", 15.5, MID, "start"))
    return _save("heat-training", "hb-timeline.svg", W, H, b, "Haemoglobin mass during five weeks of heat training and two weeks after stopping")


def detraining():
    """Line chart: VO2max after stopping training (Coyle 1984)."""
    rows = _rows("adaptation", "coyle1984.csv")
    W, H, left, right, top, base = 680, 340, 70, 520, 40, 252
    X = lambda d: left + d / 84 * (right - left)
    Y = lambda p: top + (-p) / 20 * (base - top)
    b = []
    for p in (0, -5, -10, -15, -20):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 5, f"−{-p}%" if p else "0", 15.5, MID, "end"))
    for d in (0, 21, 56, 84):
        b.append(text(X(d), base + 26, "last session" if d == 0 else f"day {d}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 56, "Change in VO₂max after training stopped", 15.5, MID, "middle"))
    s = [(float(r["day"]), float(r["change_pct"])) for r in rows]
    b.append(f'<polyline points="{" ".join(f"{X(a):.1f},{Y(c):.1f}" for a, c in s)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for a, c in s:
        b.append(f'<circle cx="{X(a):.1f}" cy="{Y(c):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(X(21) + 12, Y(-7) - 10, "−7%", 16.5, INK, "start", "600"))
    b.append(text(X(56), Y(-16) + 28, "−16%", 16.5, INK, "middle", "600"))
    b.append(text(X(84) + 14, Y(-16) - 14, "still above", 15.5, MID, "start"))
    b.append(text(X(84) + 14, Y(-16) + 5, "people who had", 15.5, MID, "start"))
    b.append(text(X(84) + 14, Y(-16) + 24, "never trained", 15.5, MID, "start"))
    return _save("adaptation", "detraining.svg", W, H, b, "VO2max over 84 days after stopping endurance training")


def atp_cycle():
    """Diagram: ATP spent and rebuilt, and the AMP side branch that AMPK reads."""
    W = 680
    b = ['<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker>'
         '<marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{MID}"/></marker></defs>']

    def box(x, y, w, h, title, lines):
        o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>',
             text(x + w / 2, y + 28, title, 19, INK, "middle", "600")]
        for i, l in enumerate(lines):
            o.append(text(x + w / 2, y + 53 + 19 * i, l, 15.5, MID, "middle"))
        return o

    def arrow(x1, y1, x2, y2, col=INK, mk="ah", dash=""):
        return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{col}" stroke-width="2" marker-end="url(#{mk})" {dash}/>'

    h, y0 = head("A muscle senses an energy shortfall through AMP, which switches on AMPK",
                 "ATP is spent and rebuilt all the time. When rebuilding falls behind, AMP builds up.", x=10, width=660)
    b += h
    bw, bh = 250, 110
    ax, ay = 10, round(y0 + 70)   # ATP, top left
    dx, dy = 420, ay              # ADP, top right
    mx, my = 420, ay + 254        # AMP, bottom right
    kx, ky = 10, my               # AMPK, bottom left
    b += box(ax, ay, bw, bh, "ATP", ["three phosphates", "carries the energy"])
    b += box(dx, dy, bw, bh, "ADP", ["two phosphates: what is", "left when ATP is spent"])
    b += box(mx, my, bw, bh, "AMP", ["one phosphate", "rises when ADP builds up"])
    b += box(kx, ky, bw, bh, "AMPK", ["the sensor: switches on", "when AMP rises against ATP"])
    mid, cy = (ax + bw + dx) / 2, ay + bh / 2
    # spending runs left to right above the middle, rebuilding right to left below it
    b.append(arrow(ax + bw + 6, cy - 14, dx - 8, cy - 14))
    for k, l in enumerate(["Contraction", "splits off a", "phosphate and", "releases energy"]):
        b.append(text(mid, cy - 96 + 19 * k, l, 15.5, INK, "middle"))
    b.append(arrow(dx - 6, cy + 14, ax + bw + 8, cy + 14))
    for k, l in enumerate(["Mitochondria", "rebuild it, using", "oxygen and fuel"]):
        b.append(text(mid, cy + 42 + 19 * k, l, 15.5, INK, "middle"))
    dash = 'stroke-dasharray="5 4"'
    b.append(arrow(dx + bw / 2, dy + bh + 6, mx + bw / 2, my - 8, MID, "ahg", dash))
    b.append(text(dx + bw / 2 - 12, (dy + bh + my) / 2 + 4, "when demand", 15.5, MID, "end"))
    b.append(text(dx + bw / 2 - 12, (dy + bh + my) / 2 + 23, "outruns supply", 15.5, MID, "end"))
    b.append(arrow(mx - 6, my + bh / 2 + 10, kx + bw + 8, ky + bh / 2 + 10, MID, "ahg", dash))
    b.append(text(mid, my + bh / 2 - 22, "read as a", 15.5, MID, "middle"))
    b.append(text(mid, my + bh / 2 - 3, "fuel gauge", 15.5, MID, "middle"))
    note, y = para(W / 2, my + bh + 34, "Solid arrows: the cycle that runs all the time. Dashed arrows: what happens when it falls behind.", 15.5, MID, 640, anchor="middle")
    b += note
    return _save("adaptation", "atp-cycle.svg", W, round(y - 6), b, "ATP is spent to ADP and rebuilt; when ADP builds up, AMP rises and AMPK switches on")


def sawtooth():
    """Two-panel time series: PGC-1a mRNA bursts and protein build-up over seven sessions (Perry 2010)."""
    W, left, right = 680, 84, 660
    step = (right - left - 30) / 6.6
    xs = lambda i: left + 14 + (i - 1) * step          # start of session i
    b = []
    # ---- panel A: mRNA, fold of the starting level
    at, ab = 78, 218
    YA = lambda f: ab - (f - 1) / 10 * (ab - at)
    b.append(text(14, at - 46, "PGC-1α messenger RNA", 18, INK, "start", "600"))
    b.append(text(14, at - 23, "a burst after every session, gone within a day", 15.5, MID, "start"))
    for f in (1, 5, 10):
        b.append(f'<line x1="{left}" y1="{YA(f):.1f}" x2="{right}" y2="{YA(f):.1f}" stroke="{INK if f == 1 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, YA(f) + 5, "start" if f == 1 else f"{f}×", 15.5, MID, "end"))
    peaks = {1: 10.8, 2: 9.3, 3: 8.1, 4: 7.1, 5: 6.2, 6: 5.5, 7: 4.9}   # only the first is a reported value
    for i, pk in peaks.items():
        meas = i in (1, 3, 5, 7)
        col, dash = (INK, "") if meas else (FAINT, 'stroke-dasharray="4 3"')
        x0 = xs(i)
        b.append(f'<polyline points="{x0:.1f},{YA(1):.1f} {x0 + step * 0.16:.1f},{YA(pk):.1f} {x0 + step * 0.55:.1f},{YA(1):.1f}" '
                 f'fill="none" stroke="{col}" stroke-width="2" stroke-linejoin="round" {dash}/>')
    b.append(text(xs(1) + step * 0.16 + 14, YA(10.8) + 6, "more than 10×, four hours after session 1", 15.5, INK, "start", "600"))
    b.append(text(xs(5) + step * 0.3, YA(8.4), "smaller each time", 15.5, MID, "start"))
    # ---- panel B: protein, per cent above the start
    bt, bb = 330, 450
    YB = lambda p: bb - p / 50 * (bb - bt)
    b.append(text(14, bt - 46, "PGC-1α protein", 18, INK, "start", "600"))
    b.append(text(14, bt - 23, "rises after the first session and does not fall back", 15.5, MID, "start"))
    for p in (0, 25, 50):
        b.append(f'<line x1="{left}" y1="{YB(p):.1f}" x2="{right}" y2="{YB(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, YB(p) + 5, "start" if p == 0 else f"+{p}%", 15.5, MID, "end"))
    pts = [(left, 0), (xs(1) + step * 0.55, 23), (xs(5) + step * 0.55, 42), (xs(7) + step * 0.55, 42)]
    b.append(f'<polyline points="{" ".join(f"{x:.1f},{YB(v):.1f}" for x, v in pts)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round" stroke-dasharray="6 4"/>')
    for x, v in pts[1:]:
        b.append(f'<circle cx="{x:.1f}" cy="{YB(v):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(pts[1][0] + 10, YB(23) + 20, "+23%", 16.5, INK, "start", "600"))
    b.append(text(pts[2][0], YB(42) - 14, "+42%", 16.5, INK, "middle", "600"))
    b.append(text(pts[3][0], YB(42) - 14, "+42%", 16.5, INK, "middle", "600"))
    # ---- shared session axis and the later arrivals
    for i in range(1, 8):
        for y in (ab, bb):
            b.append(f'<line x1="{xs(i):.1f}" y1="{y}" x2="{xs(i):.1f}" y2="{y + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(xs(i), ab + 26, str(i), 15.5, MID, "middle"))
        b.append(text(xs(i), bb + 26, str(i), 15.5, MID, "middle"))
    b.append(text(left - 10, ab + 26, "session", 15.5, MID, "end"))
    b.append(text(left - 10, bb + 26, "session", 15.5, MID, "end"))
    for i, l1, l2, anchor, dx in ((3, "citrate synthase activity", "first up: +17%", "end", 24), (5, "COX-IV protein", "first up: +20%", "start", -24)):
        x = xs(i) + step * 0.3
        b.append(f'<path d="M{x:.1f},{bb + 34} l-5,9 h10 z" fill="{INK}"/>')
        b.append(text(x + dx, bb + 64, l1, 15.5, INK, anchor))
        b.append(text(x + dx, bb + 83, l2, 15.5, INK, anchor))
    return _save("adaptation", "sawtooth.svg", W, bb + 96, b, "PGC-1 alpha messenger RNA bursts and protein build-up across seven training sessions")


def pain_training():
    """Bar chart: change in pain tolerance and time to exhaustion by training group (O'Leary 2017)."""
    rows = _rows("effort-and-pain", "oleary2017.csv")
    b, y0 = head("Both groups got fitter, but only the interval group's pain tolerance rose",
                 "Change after six weeks in 20 healthy adults: time lasted in a tourniquet test on the arm, "
                 "and time to exhaustion at the same hard power as before.", x=10, width=660)
    W, left, right, top, rh, gap = 680, 250, 560, round(y0 + 40), 42, 26
    lo, hi = -20.0, 160.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    n_groups = len({r["measure"] for r in rows})
    base = top + rh * len(rows) + gap * (n_groups - 1) + 26 * n_groups
    for v in (0, 50, 100, 150):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{INK if v == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"+{v}%" if v else "0", 15.5, MID, "middle"))
    b.append(text((X(0) + right) / 2, base + 50, "Change after six weeks of training", 15.5, MID, "middle"))
    y, last = top, None
    for r in rows:
        if last is not None and r["measure"] != last:
            y += gap
        if r["measure"] != last:
            b.append(text(left - 44, y + 12, r["measure"], 16.5, INK, "end", "600"))
            y += 26
        last = r["measure"]
        v = float(r["change_pct"])
        hard = r["group"].startswith("Hard")
        b.append(text(left - 44, y + 18, r["group"], 15.5, INK if hard else MID, "end"))
        x0, x1 = sorted((X(0), X(v)))
        b.append(f'<rect x="{x0:.1f}" y="{y + 4}" width="{max(x1 - x0, 1.5):.1f}" height="22" rx="3" fill="{INK if hard else FAINT}"/>')
        lab = (f"+{v:.0f}%" if v > 0 else f"−{-v:.0f}%")
        b.append(text(X(max(v, 0)) + 10, y + 21, lab, 16.5, INK, "start", "600"))
        y += rh
    return _save("effort-and-pain", "pain-training.svg", W, base + 66, b, "Change in pain tolerance and time to exhaustion after six weeks of hard intervals or steady riding")


def small_trials():
    """Two histograms on one scale: results of 20,000 simulated trials with 10 and with 50 people per group."""
    rows = _rows("reading-research", "small-trials.csv")
    W, left, right = 680, 30, 660
    lo, hi = -6, 13
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    bw = X(0.5) - X(0)
    mx = 0.21                           # one vertical scale for both panels, so bar heights compare directly
    b, y = head("Small trials that reach significance overstate the effect",
                "Results of 20,000 simulated trials of a method whose real advantage is 3 points.", left, 630)
    # (n, title, subtitle, wrong-direction note, note on the significant trials, their mean)
    panels = [(10, "10 people in each group", "25% of trials reached statistical significance (black); 75% did not (grey).",
               "9% favoured the wrong method", "significant trials averaged +5.7", 5.7),
              (50, "50 people in each group", "84% of trials reached statistical significance (black); 16% did not (grey).",
               "0.1% favoured the wrong method", "significant trials averaged +3.3", 3.3)]
    for n, title, sub, wrong, sigtxt, sigmean in panels:
        b.append(text(left, y + 34, title, 18, INK, "start", "600"))
        s, y = para(left, y + 57, sub, 15.5, MID, 630)
        b += s
        top = y + 16
        base = top + 170
        sel = [r for r in rows if int(r["n"]) == n]
        Y = lambda sh: base - sh / mx * (base - top)
        b.append(f'<rect x="{X(lo):.1f}" y="{top}" width="{X(0) - X(lo):.1f}" height="{base - top}" fill="#f3f3f3"/>')
        for r in sel:
            x, sh, sg = X(float(r["lo"])), float(r["share"]), float(r["sig_share"])
            if sh > 0.0005:
                b.append(f'<rect x="{x + 0.5:.1f}" y="{Y(sh):.1f}" width="{bw - 1:.1f}" height="{base - Y(sh):.1f}" fill="{FAINT}"/>')
            if sg > 0.0005:
                b.append(f'<rect x="{x + 0.5:.1f}" y="{Y(sg):.1f}" width="{bw - 1:.1f}" height="{base - Y(sg):.1f}" fill="{INK}"/>')
        b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{INK}" stroke-width="1"/>')
        b.append(f'<line x1="{X(3):.1f}" y1="{top}" x2="{X(3):.1f}" y2="{base}" stroke="{INK}" stroke-width="1.5" stroke-dasharray="5 4"/>')
        b.append(text(X(3), top - 7, "true advantage +3", 15.5, INK, "middle"))
        b.append(text(X(lo) + 6, top + 20, wrong, 15.5, MID, "start"))
        b.append(text(X(lo) + 6, top + 39, "(shaded area)", 15, MID, "start"))
        b.append(text(right, top + 20, sigtxt, 15.5, INK, "end", "600"))
        if n == 10:
            b.append(f'<line x1="{X(sigmean):.1f}" y1="{top + 28}" x2="{X(sigmean):.1f}" y2="{base - 40}" stroke="{INK}" stroke-width="1"/>')
            b.append(f'<path d="M{X(sigmean) - 4:.1f},{base - 46} L{X(sigmean) + 4:.1f},{base - 46} L{X(sigmean):.1f},{base - 38} Z" fill="{INK}"/>')
        for v in range(-6, 13, 3):
            b.append(text(X(v), base + 22, ("−" + str(-v)) if v < 0 else (f"+{v}" if v else "0"), 15.5, MID, "middle"))
        y = base + 22
    b.append(text((left + right) / 2, y + 28, "Advantage the trial measured for the better method (points)", 15.5, MID, "middle"))
    return _save("reading-research", "small-trials.svg", W, y + 44, b, "Results of 20,000 simulated trials of the same true effect, with 10 and with 50 people per group")


def carb_curve():
    """Line chart: time-trial gain against carbohydrate dose (Smith 2013)."""
    rows = _rows("fuelling", "smith2013.csv")
    b, y = head("Most of the gain from carbohydrate arrives by 50 grams an hour",
                "Improvement in a 20 km time trial after a two-hour ride, against a placebo drink. 51 cyclists.")
    W, left, right = 680, 70, 600
    top = y + 34
    base = top + 200
    H = base + 70
    X = lambda d: left + d / 120 * (right - left)
    Y = lambda p: base - p / 5 * (base - top)
    b.append(f'<rect x="{X(78):.1f}" y="{top}" width="{X(120) - X(78):.1f}" height="{base - top}" fill="#f3f3f3"/>')
    for p in range(0, 6):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 5, f"+{p}%" if p else "0", 15.5, MID, "end"))
    for d in range(0, 121, 30):
        b.append(text(X(d), base + 24, str(d), 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 52, "Carbohydrate drunk during the ride (grams an hour)", 15.5, MID, "middle"))
    s = [(float(r["dose_g_h"]), float(r["gain_pct"])) for r in rows]
    b.append(f'<polyline points="{" ".join(f"{X(a):.1f},{Y(c):.1f}" for a, c in s)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for a, c in s[1:]:
        b.append(f'<circle cx="{X(a):.1f}" cy="{Y(c):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(X(48) - 12, Y(4.0) - 12, "+4.0% at 48", 16.5, INK, "end", "600"))
    b.append(text(X(78), Y(4.7) - 16, "+4.7% at 78, the peak", 16.5, INK, "middle", "600"))
    for k, (l, size) in enumerate((("above 78 the", 15.5), ("benefit shrank", 15.5), ("(sizes not reported", 15), ("in the abstract)", 15))):
        b.append(text(X(99), Y(2.9) + 19 * k, l, size, MID, "middle"))
    return _save("fuelling", "carb-curve.svg", W, H, b, "Time-trial improvement against carbohydrate dose, from Smith 2013")


def strength_effects():
    """Interval plot: pooled effects of heavy strength training in cyclists (Llanos-Lagos 2026)."""
    rows = _rows("strength", "llanos2026.csv")
    b, y = head("Lifting makes cyclists faster without raising VO₂max or threshold",
                "Pooled effect of adding heavy strength training, from 17 controlled studies of cyclists. "
                "Lines are 95% confidence intervals; a line that crosses zero means no clear effect.")
    W, left, right, rh = 680, 200, 520, 50
    top = y + 30
    H = top + rh * len(rows) + 70
    lo, hi = -0.6, 1.2
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows)
    for v in (-0.5, 0.5, 1.0):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{FAINT}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v:+.1f}".replace("-", "−"), 15.5, MID, "middle"))
    b.append(f'<line x1="{X(0):.1f}" y1="{top - 8}" x2="{X(0):.1f}" y2="{base}" stroke="{INK}" stroke-width="1"/>')
    b.append(text(X(0), base + 22, "0", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 50, "Effect size (standard deviations; 0.2 is small, 0.5 moderate)", 15.5, MID, "middle"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 4
        est, a, c = float(r["estimate"]), float(r["low"]), float(r["high"])
        b.append(text(left - 18, y - 4, r["measure"], 16.5, INK, "end", "600"))
        b.append(text(left - 18, y + 15, r["setting"], 15.5, MID, "end"))
        b.append(f'<line x1="{X(a):.1f}" y1="{y:.1f}" x2="{X(c):.1f}" y2="{y:.1f}" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
        b.append(f'<circle cx="{X(est):.1f}" cy="{y:.1f}" r="5.5" fill="{INK if a > 0 else "#ffffff"}" stroke="{INK}" stroke-width="2"/>')
        b.append(text(right + 18, y + 5, f"{est:+.2f}".replace("-", "−"), 16.5, INK, "start", "600"))
        b.append(text(right + 74, y + 5, "clear" if a > 0 else "not clear", 15.5, MID, "start"))
    return _save("strength", "strength-effects.svg", W, H, b, "Pooled effects of heavy strength training on six measures in cyclists, from Llanos-Lagos 2026")


def zone_maps():
    """Schematic: a lactate curve, the two thresholds, and three ways of dividing the intensity range."""
    b, y = head("Zone 2 is in a different place in each system",
                "Blood lactate in a test of rising power (a sketch, not data), the two thresholds, "
                "and four ways of dividing the range. Each system's second zone is shaded. Coggan's levels are "
                "placed for a rider whose FTP sits at the second threshold.")
    W = 680
    left, right = 60, 640
    top = y + 36
    base = top + 150
    t1, t2 = left + 0.45 * (right - left), left + 0.72 * (right - left)
    b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    b.append(f'<line x1="{left}" y1="{top}" x2="{left}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    b.append(text(left - 14, (top + base) / 2, "Blood lactate", 15.5, MID, "middle", style=f'transform="rotate(-90 {left - 14} {(top + base) / 2})"'))
    b.append(text(right, base + 22, "Power →", 15.5, MID, "end"))
    b.append(text(left, base + 22, "Easy", 15.5, MID, "start"))
    y0 = base - 22
    b.append(f'<path d="M{left},{y0} L{t1 - 40:.1f},{y0} Q{t1:.1f},{y0} {t1 + 40:.1f},{y0 - 12} '
             f'C{t2 - 40:.1f},{y0 - 34} {t2 + 20:.1f},{y0 - 60} {t2 + 60:.1f},{y0 - 105} L{t2 + 80:.1f},{y0 - 128}" '
             f'fill="none" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
    for x, lab in ((t1, "First threshold"), (t2, "Second threshold")):
        b.append(f'<line x1="{x:.1f}" y1="{top + 14}" x2="{x:.1f}" y2="{base}" stroke="{MID}" stroke-width="1" stroke-dasharray="4 4"/>')
        b.append(text(x, top + 4, lab, 15.5, INK, "middle", "600"))
    rows = [("What the body does: intensity domains", [(left, t1, "Moderate", 0), (t1, t2, "Heavy", 0), (t2, right, "Severe", 0)]),
            ("Three-zone model, used in most research", [(left, t1, "Zone 1", 0), (t1, t2, "Zone 2", 1), (t2, right, "Zone 3", 0)]),
            ("Five-zone model, used by the Norwegian federation and most apps",
             [(left, (left + t1) / 2, "Zone 1", 0), ((left + t1) / 2, t1, "Zone 2", 1), (t1, t2, "Zone 3", 0),
              (t2, (t2 + right) / 2, "Zone 4", 0), ((t2 + right) / 2, right, "Zone 5", 0)])]
    # Coggan's levels are percentages of FTP; with FTP at the second threshold, power is t2 * fraction.
    P = lambda f: min(right, left + f * (t2 - left))
    cuts = [0, 0.555, 0.755, 0.905, 1.055, 1.205, 9]
    names = ["Level 1", "Level 2", "3", "4", "5", "6–7"]
    rows.append(("Coggan's power levels, percentages of FTP, used in most power software",
                 [(P(a), P(c), n, int(n == "Level 2")) for a, c, n in zip(cuts, cuts[1:], names)]))
    y = base + 56
    labels = []   # drawn last, each on a patch of its background, so the threshold lines run behind them

    def patch(x, y, s, size, fill, anchor):
        w = len(s) * size * 0.56 + 8
        x0 = x - w / 2 if anchor == "middle" else x - 4
        return f'<rect x="{x0:.1f}" y="{y - size * 0.85:.1f}" width="{w:.1f}" height="{size * 1.15:.1f}" fill="{fill}"/>'

    for label, cells in rows:
        labels += [patch(left, y, label, 15.5, "#ffffff", "start"), text(left, y, label, 15.5, MID, "start")]
        for a, c, name, hit in cells:
            fill = BAND if hit else "#ffffff"
            b.append(f'<rect x="{a + 1:.1f}" y="{y + 8}" width="{c - a - 2:.1f}" height="30" fill="{fill}" stroke="{INK if hit else FAINT}" stroke-width="{1.5 if hit else 1}"/>')
            labels += [patch((a + c) / 2, y + 29, name, 16.5, fill, "middle"),
                       text((a + c) / 2, y + 29, name, 16.5, INK, "middle", "600" if hit else "400")]
        y += 64
    for x in (t1, t2):
        b.append(f'<line x1="{x:.1f}" y1="{base}" x2="{x:.1f}" y2="{y - 18}" stroke="{MID}" stroke-width="1" stroke-dasharray="4 4"/>')
    b += labels
    return _save("intensity", "zone-maps.svg", W, y - 12, b, "Sketch of a lactate curve with two thresholds, and beneath it the intensity domains, the three-zone and five-zone models and Coggan's power levels, each with its second zone shaded in a different place")


def zone2_markers():
    """Dot plot: mean power at nine markers of Zone 2 in the same 50 cyclists (Meixner 2025)."""
    rows = _rows("intensity", "meixner2025.csv")
    b, y = head("Nine markers of Zone 2 span about 100 watts in the same riders",
                "Average power at each marker in 50 trained cyclists tested in one laboratory, "
                "with the heart rate at that power as a percentage of maximum.")
    W, left, right, rh = 680, 340, 560, 46
    top = y + 40
    H = top + rh * len(rows) + 50
    lo, hi = 100.0, 250.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows)
    b.append(f'<line x1="{X(lo):.1f}" y1="{base}" x2="{X(hi):.1f}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (100, 150, 200, 250):
        b.append(f'<line x1="{X(v):.1f}" y1="{base}" x2="{X(v):.1f}" y2="{base + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 24, f"{v} W", 15.5, MID, "middle"))
    b.append(text(670, top - 16, "heart rate", 15.5, MID, "end"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 4
        p = float(r["power"])
        b.append(text(left - 16, y + (-4 if r["note"] else 5), r["marker"], 16.5, INK, "end", "600"))
        if r["note"]:
            b.append(text(left - 16, y + 15, r["note"], 15, MID, "end"))
        b.append(f'<line x1="{X(lo):.1f}" y1="{y:.1f}" x2="{X(p):.1f}" y2="{y:.1f}" stroke="{FAINT}" stroke-width="1"/>')
        b.append(f'<circle cx="{X(p):.1f}" cy="{y:.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        b.append(text(X(p) + 12, y + 5, f"{p:.0f} W", 16.5, INK, "start", "600"))
        b.append(text(670, y + 5, f'{r["hr"]}%', 15.5, MID, "end"))
    return _save("intensity", "zone2-markers.svg", W, H, b, "Average power at nine markers of Zone 2 in 50 trained cyclists, from Meixner 2025")


def threshold_percent():
    """Four range bars on one scale: two rules for Zone 2, and where the first lactate threshold was measured, as % of maximum heart rate."""
    rows = _rows("finding-zones", "threshold-percent.csv")
    b, y = head("No fixed percentage of maximum heart rate finds the first threshold",
                "Every bar is a range of heart rates, as a percentage of the person’s own maximum. "
                "The first threshold is the top of Zone 2.")
    W, left, right, rh, gap = 680, 300, 640, 50, 50
    top = y + 58
    lo, hi = 50.0, 95.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows) + gap + 6
    for v in (50, 60, 70, 80, 90):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 30}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
    b.append(f'<line x1="{X(lo):.1f}" y1="{base}" x2="{X(hi):.1f}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (50, 60, 70, 80, 90):
        b.append(f'<line x1="{X(v):.1f}" y1="{base}" x2="{X(v):.1f}" y2="{base + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 24, f"{v}%", 15.5, MID, "middle"))
    b.append(text((X(lo) + X(hi)) / 2, base + 50, "Percentage of maximum heart rate", 15.5, MID, "middle"))
    heads = {"rule": "Open bars: where two rules put Zone 2",
             "measured": "Solid bars: where the first lactate threshold was measured"}
    y0, seen = top, None
    for r in rows:
        if r["kind"] != seen:
            if seen is not None:
                y0 += gap
            sw = (f'<rect x="30" y="{y0 - 27:.1f}" width="22" height="14" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>'
                  if r["kind"] == "rule" else f'<rect x="30" y="{y0 - 27:.1f}" width="22" height="14" fill="{INK}"/>')
            b.append(sw)
            b.append(text(62, y0 - 14, heads[r["kind"]], 16.5, MID, "start", "600", 'paint-order="stroke" stroke="#ffffff" stroke-width="6"'))
            seen = r["kind"]
        y = y0 + rh / 2
        a, c = float(r["lo"]), float(r["hi"])
        b.append(text(left - 56, y - 3, r["label"], 16.5, INK, "end", "600"))
        b.append(text(left - 56, y + 16, r["note"], 15, MID, "end"))
        if r["kind"] == "rule":
            b.append(f'<rect x="{X(a):.1f}" y="{y - 8:.1f}" width="{X(c) - X(a):.1f}" height="16" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>')
        else:
            b.append(f'<rect x="{X(a):.1f}" y="{y - 8:.1f}" width="{X(c) - X(a):.1f}" height="16" fill="{INK}"/>')
        b.append(text(X(a) - 7, y + 5, f"{a:.0f}%", 15.5, INK, "end", "600", 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'))
        b.append(text(X(c) + 7, y + 5, f"{c:.0f}%", 15.5, INK, "start", "600", 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'))
        y0 += rh
    note, y = para(30, base + 84, "A rule fits a rider only if its upper end, 70% or 82%, is where that rider’s threshold falls.")
    b += note
    return _save("finding-zones", "threshold-percent.svg", W, round(y - 6), b, "Four range bars on a scale of percentage of maximum heart rate: two rules for Zone 2, at 60 to 70 and 72 to 82 percent, and the measured first lactate threshold, at 78 to 84 percent in two thirds of 50 trained cyclists and from 60 to 90 percent across 100 adults")


def lactate_steps():
    """Schematic of a step test read two ways: lactate against the rider's baseline, and the talk test. Values are made up."""
    b, y = head("Zone 2 ends at the last stage before lactate rises",
                "A step test of four-minute stages, about 15 W apart, with made-up values: blood lactate "
                "at the end of each stage, and the answer to “Could I speak comfortably?”")
    W = 680
    left, right = 96, 650
    top = y + 40
    base = top + 196
    vals = [1.1, 1.0, 1.1, 1.2, 1.3, 1.9, 2.8]
    talk = ["yes", "yes", "yes", "yes", "yes", "not sure", "no"]
    n = len(vals)
    sw = (right - left) / n
    Y = lambda v: base - v / 3.2 * (base - top)
    cx = lambda i: left + (i + 0.5) * sw
    bl = sum(vals[:4]) / 4
    hit = 4
    b.append(f'<rect x="{left + hit * sw + 3:.1f}" y="{top - 6}" width="{sw - 6:.1f}" height="{base - top + 70}" fill="{BAND}"/>')
    b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    b.append(f'<line x1="{left}" y1="{top}" x2="{left}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (0, 1, 2, 3):
        b.append(f'<line x1="{left - 5}" y1="{Y(v):.1f}" x2="{left}" y2="{Y(v):.1f}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 5, str(v), 15.5, MID, "end"))
    b.append(text(left - 44, (top + base) / 2, "Blood lactate (mmol/L)", 15.5, MID, "middle", style=f'transform="rotate(-90 {left - 44} {(top + base) / 2})"'))
    for v, lab in ((bl, "baseline"), (bl + 0.5, "baseline + 0.5")):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{MID}" stroke-width="1" stroke-dasharray="4 4"/>')
        b.append(text(right - 4, Y(v) + 17, lab, 15, MID, "end"))
    pts = " ".join(f"{cx(i):.1f},{Y(v):.1f}" for i, v in enumerate(vals))
    b.append(f'<polyline points="{pts}" fill="none" stroke="{INK}" stroke-width="2"/>')
    for i, v in enumerate(vals):
        b.append(f'<circle cx="{cx(i):.1f}" cy="{Y(v):.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        ly = Y(v) + 25 if i == 4 else (Y(v) - 13 if i < 5 else Y(v) - 7)
        halo = f'paint-order="stroke" stroke="{BAND}" stroke-width="5"' if i == 4 else ""
        b.append(text(cx(i) + (0 if i < 5 else -14), ly, f"{v:.1f}", 15.5, INK, "middle" if i < 5 else "end", "600", halo))
        b.append(text(cx(i), base + 24, f"stage {i + 1}", 15, MID, "middle"))
        b.append(text(cx(i), base + 54, talk[i], 15.5, INK, "middle", "600" if i >= 4 else "400"))
    b.append(text(left - 10, base + 54, "speak?", 15.5, MID, "end"))
    # The early readings wobble (stage 2 below stage 1): say so on the chart, as step 6 of the test does.
    by, x0, x1 = Y(1.95), cx(0) - 14, cx(3) + 14
    b.append(f'<path d="M{x0:.1f},{by + 8:.1f} V{by:.1f} H{x1:.1f} V{by + 8:.1f}" fill="none" stroke="{MID}" stroke-width="1.2"/>')
    b.append(text((x0 + x1) / 2, by - 24, "Early readings wobble by a tenth", 15, MID, "middle"))
    b.append(text((x0 + x1) / 2, by - 7, "or two; their average is the baseline", 15, MID, "middle"))
    b.append(text(cx(hit), top + 12, "top of", 15.5, INK, "middle"))
    b.append(text(cx(hit), top + 31, "Zone 2", 16.5, INK, "middle", "600"))
    note, y = para(30, base + 96, "The first four readings differ by a tenth or two, as a meter’s will, and stage 2 reads lower than stage 1. Their average, 1.1, is the baseline. "
                   "Stage 6 is the first to read 0.5 mmol/L above it, and stage 7 confirms it by reading higher still. "
                   "The top of Zone 2 is the power and heart rate of stage 5.")
    b += note
    return _save("finding-zones", "lactate-steps.svg", W, round(y - 6), b, "Sketch of a seven-stage step test: lactate flat for five stages then rising, with talk-test answers of yes, not sure and no")


def mito_efficiency():
    """Two bar panels: change in mitochondrial content per programme and per hour, by kind of training (Mølmen 2025)."""
    rows = _rows("easy-riding", "molmen2025.csv")
    b, y = head("Continuous riding adds as much mitochondrial content as intervals, in more hours",
                "Change in the muscle’s mitochondrial content after a training programme, and the same change "
                "per hour of training relative to continuous riding. Pooled from 353 studies.")
    W, rh = 680, 58
    top = y + 52
    base = top + rh * len(rows)
    panels = [(190, 400, "After a whole programme", "change", 30.0, lambda v: f"+{v:.0f}%"),
              (470, 630, "Per hour of training", "efficiency", 4.2, lambda v: f"{v:.1f}×")]
    for x0, x1, headline, key, vmax, fmt in panels:
        b.append(text(x0, top - 18, headline, 16.5, INK, "start", "600"))
        b.append(f'<line x1="{x0}" y1="{top - 6}" x2="{x0}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
        for i, r in enumerate(rows):
            v = float(r[key])
            y = top + rh * i + 10
            w = v / vmax * (x1 - x0)
            b.append(f'<rect x="{x0}" y="{y}" width="{w:.1f}" height="24" fill="{INK if i == 0 else FAINT}"/>')
            b.append(text(x0 + w + 8, y + 18, fmt(v), 16.5, INK, "start", "600"))
    for i, r in enumerate(rows):
        words = r["label"].split(" ")
        y = top + rh * i + 10
        b.append(text(170, y + 8, " ".join(words[:-1]) or words[0], 16.5, INK, "end", "600"))
        b.append(text(170, y + 27, words[-1] if len(words) > 1 else "", 16.5, INK, "end", "600"))
    note, y = para(30, base + 34, "Continuous riding here means everything below the second threshold, easy and moderate together.")
    b += note
    return _save("easy-riding", "mito-efficiency.svg", W, round(y - 6), b, "Bar charts of the change in mitochondrial content after continuous, interval and sprint training, per programme and per hour")


def fatmax_feeding():
    """Dot plot, one row per feeding condition: peak fat burning (circle) and, where measured, the first lactate rise (square)."""
    rows = _rows("easy-riding", "fatmax-feeding.csv")
    b, y = head("Carbohydrate before a ride moved peak fat burning to a lower intensity",
                "Where fat burning peaked, and where blood lactate first rose, as a percentage of VO₂max, in three "
                "separate studies. Compare points within a study, not across them: each tested different people "
                "in a different way.")
    W, left, right, rh, sh = 680, 300, 640, 52, 34
    ky = y + 30
    top = ky + 40
    lo, hi = 45.0, 75.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    studies = list(dict.fromkeys(r["study"] for r in rows))
    base = top + rh * len(rows) + sh * len(studies)
    H = base + 64
    b.append(f'<circle cx="36" cy="{ky}" r="5.5" fill="{INK}"/>')
    b.append(text(50, ky + 5, "Peak fat burning", 15.5, INK, "start", "600"))
    b.append(f'<rect x="{224}" y="{ky - 5.5}" width="11" height="11" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
    b.append(text(244, ky + 5, "First rise in blood lactate", 15.5, INK, "start", "600"))
    for v in (45, 50, 55, 60, 65, 70, 75):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
    b.append(f'<line x1="{X(lo):.1f}" y1="{base}" x2="{X(hi):.1f}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (45, 50, 55, 60, 65, 70, 75):
        b.append(f'<line x1="{X(v):.1f}" y1="{base}" x2="{X(v):.1f}" y2="{base + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 24, f"{v}%", 15.5, MID, "middle"))
    b.append(text((X(lo) + X(hi)) / 2, base + 50, "Percentage of VO₂max", 15.5, MID, "middle"))
    halo = 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'
    y0, last = top, None
    for r in rows:
        if r["study"] != last:
            if last is not None:
                b.append(f'<line x1="30" y1="{y0 + 6}" x2="{right}" y2="{y0 + 6}" stroke="{FAINT}" stroke-width="1"/>')
            b.append(text(30, y0 + 26, r["study"], 15, MID, "start", "600"))
            y0 += sh
            last = r["study"]
        y = y0 + rh / 2 - 2
        y0 += rh
        b.append(text(left - 20, y - 4, r["label"], 16.5, INK, "end", "600"))
        b.append(text(left - 20, y + 15, r["note"], 15, MID, "end"))
        f = float(r["fatmax"])
        l = float(r["lactate"]) if r["lactate"] else None
        side = 1 if l is None or f > l else -1
        if l is not None:
            b.append(f'<line x1="{X(min(f, l)):.1f}" y1="{y:.1f}" x2="{X(max(f, l)):.1f}" y2="{y:.1f}" stroke="{FAINT}" stroke-width="1.5"/>')
            b.append(f'<rect x="{X(l) - 5.5:.1f}" y="{y - 5.5:.1f}" width="11" height="11" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
            b.append(text(X(l) - side * 12, y + 5, f"{l:.0f}%", 15.5, INK, "end" if side > 0 else "start", "400", halo))
        b.append(f'<circle cx="{X(f):.1f}" cy="{y:.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        b.append(text(X(f) + side * 12, y + 5, f"{f:.0f}%", 15.5, INK, "start" if side > 0 else "end", "600", halo))
    return _save("easy-riding", "fatmax-feeding.svg", W, H, b, "Three separate studies. Peak fat burning at 63, 60, 52 and 56 percent of VO2max in four feeding conditions, with the first lactate rise at 61 percent in the first and 69 percent in the last")


def elite_distributions():
    """Stacked bars: share of training time below, between and above the thresholds in seven groups of elite athletes."""
    rows = _rows("elites", "elite-distributions.csv")
    b, y = head("Elite training is mostly easy, but road cyclists do more in the middle",
                "Share of endurance training time in seven groups of elite athletes, most easy at the top. "
                "The studies counted in different ways, noted under each name.")
    W, left, right, rh = 680, 330, 550, 48
    X = lambda v: left + v / 100.0 * (right - left)
    fills = (BAND, MID, INK)
    ky = y + 30
    for fill, lab, dx, dy in ((BAND, "Below the first threshold", 0, 0), (MID, "Between the thresholds", 300, 0), (INK, "Above the second threshold", 0, 24)):
        b.append(f'<rect x="{30 + dx}" y="{ky + dy - 6}" width="12" height="12" fill="{fill}" stroke="{MID}" stroke-width="0.75"/>')
        b.append(text(30 + dx + 20, ky + dy + 5, lab, 15.5, INK, "start", "600"))
    top = ky + 64
    base = top + rh * len(rows)
    H = base + 64
    for v in (0, 25, 50, 75, 100):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 6}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v}%", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 48, "Share of endurance training time", 15.5, MID, "middle"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 2
        b.append(text(left - 14, y - 4, r["label"], 16.5, INK, "end", "600"))
        b.append(text(left - 14, y + 15, r["note"], 15, MID, "end"))
        vals = [float(r[k]) for k in ("easy", "middle", "hard")]
        x = 0.0
        for v, fill in zip(vals, fills):
            w = max(X(x + v) - X(x) - 2, 0.6)
            b.append(f'<rect x="{X(x):.1f}" y="{y - 10:.1f}" width="{w:.1f}" height="20" fill="{fill}"/>')
            x += v
        b.append(text(right + 12, y + 5, " / ".join(f"{v:.0f}" for v in vals), 16.5, INK, "start", "600"))
    return _save("elites", "elite-distributions.svg", W, H, b, "Stacked bars of training time below the first threshold, between the thresholds and above the second in seven groups of elite athletes, from 95, 2 and 3 percent in junior rowers to 22, 68 and 10 percent in under-23 professional cyclists")


def champions_week():
    """Stacked bars: weekly easy and hard hours of 11 champion skiers by phase (Tønnessen 2014), with one illustrative seven-hour week."""
    rows = _rows("elites", "champions-week.csv")
    b, y = head("The champions’ hard training stayed near 1.3 hours a week while the easy hours changed",
                "Weekly hours of endurance training below and above the first lactate threshold: eleven Olympic "
                "and world champion skiers in the year of their gold medal, by phase of the season.")
    W, left, right, rh, gap = 680, 230, 500, 52, 30
    hi = 18.0
    X = lambda v: left + v / hi * (right - left)
    ky = y + 30
    b.append(f'<rect x="{left}" y="{ky - 6}" width="12" height="12" fill="{BAND}" stroke="{MID}" stroke-width="0.75"/>')
    b.append(text(left + 20, ky + 5, "Below the first threshold", 15.5, INK, "start", "600"))
    b.append(f'<rect x="{left + 250}" y="{ky - 6}" width="12" height="12" fill="{INK}"/>')
    b.append(text(left + 270, ky + 5, "Above it", 15.5, INK, "start", "600"))
    top = ky + 30
    base = top + rh * len(rows) + gap
    for v in (0, 5, 10, 15):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 6}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v}", 15.5, MID, "middle"))
    b.append(text((X(0) + X(15)) / 2, base + 48, "Hours a week", 15.5, MID, "middle"))
    y0 = top
    for r in rows:
        if r["kind"] == "example":
            y0 += gap
            b.append(f'<line x1="30" y1="{y0 - gap / 2 - 2:.1f}" x2="{W - 30}" y2="{y0 - gap / 2 - 2:.1f}" stroke="{FAINT}" stroke-width="1" stroke-dasharray="3 4"/>')
        y = y0 + rh / 2 - 2
        e, h = float(r["easy"]), float(r["hard"])
        b.append(text(left - 16, y - 4, r["label"], 16.5, INK, "end", "600"))
        b.append(text(left - 16, y + 15, r["note"], 15, MID, "end"))
        b.append(f'<rect x="{X(0):.1f}" y="{y - 11:.1f}" width="{X(e) - X(0) - 2:.1f}" height="22" fill="{BAND}"/>')
        b.append(f'<rect x="{X(e):.1f}" y="{y - 11:.1f}" width="{X(e + h) - X(e):.1f}" height="22" fill="{INK}"/>')
        b.append(text(X(e) - 8, y + 5, f"{e:.1f}", 15.5, INK, "end", "400"))
        b.append(text(X(e + h) + 10, y - 4, f"{h:.1f} h hard", 16.5, INK, "start", "600"))
        b.append(text(X(e + h) + 10, y + 15, f"{h / (e + h) * 100:.0f}% of {e + h:.1f} h", 15, MID, "start"))
        y0 += rh
    note, y = para(30, base + 84, "The last row is not data. It shows the same hard training inside a seven-hour week.")
    b += note
    return _save("elites", "champions-week.svg", W, round(y - 6), b, "Weekly hours below and above the first lactate threshold for eleven champion skiers: 15.2 and 1.3 in general preparation, 14.4 and 1.3 in specific preparation, 9.8 and 1.4 in competition, beside an illustrative seven-hour week with 5.7 and 1.3")


def dose_response():
    """Bars: lower risk of death by amount of leisure activity, in multiples of the guideline minimum (Arem 2015)."""
    rows = _rows("beyond-performance", "arem2015.csv")
    b, y = head("Most of the lower risk comes with the first few hours a week",
                "Risk of death against people who reported no leisure activity, by multiples of the guideline "
                "minimum of 150 minutes of moderate or 75 of vigorous activity a week. 661,137 adults in six cohorts.")
    W, left, right = 680, 76, 664
    top = y + 76
    base = top + 220
    H = base + 76
    n = len(rows)
    cw = (right - left) / n
    Y = lambda v: base - v / 40 * (base - top)
    xs = [left + cw * i for i in range(n)]
    band = [i for i, r in enumerate(rows) if r["rider"] == "1"]
    bx0, bx1 = xs[band[0]] + 4, xs[band[-1]] + cw - 4
    b.append(f'<rect x="{bx0:.1f}" y="{top - 20}" width="{bx1 - bx0:.1f}" height="{base - top + 20}" fill="#f3f3f3"/>')
    b.append(text(bx1, top - 50, "A trained rider on 6 to 10 hours", 15.5, INK, "end", "600"))
    b.append(text(bx1, top - 31, "a week, roughly (my estimate)", 15.5, MID, "end"))
    for v in (0, 10, 20, 30, 40):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{INK if v == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 5, f"{v}%", 15.5, MID, "end"))
    b.append(text(14, top - 22, "Lower risk of death", 15.5, MID, "start"))
    for x, r in zip(xs, rows):
        v = float(r["lower_pct"])
        bw = cw - 26
        if v > 0:
            b.append(f'<path d="M{x + 13:.1f},{base} V{Y(v) + 4:.1f} a4,4 0 0 1 4,-4 H{x + 13 + bw - 4:.1f} a4,4 0 0 1 4,4 V{base} z" fill="{MID if r["rider"] == "1" else INK}"/>')
            b.append(text(x + cw / 2, Y(v) - 9, f"{v:.0f}%", 16.5, INK, "middle", "600"))
        b.append(text(x + cw / 2, base + 24, r["category"], 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 54, "Leisure activity, in multiples of the guideline minimum", 15.5, MID, "middle"))
    return _save("beyond-performance", "dose-response.svg", W, H, b, "Bar chart of lower risk of death by amount of leisure activity: 20, 31, 37, 39 and 39 percent from under the guideline minimum to 5 to 10 times it, and 31 percent at 10 times or more")


def time_near_max():
    """Paired dots: minutes above 90% of VO2max in one session, short or varied format against a longer, steadier one."""
    rows = _rows("designing-intervals", "time-near-max.csv")
    b, y = head("Short work periods usually add time near VO₂max, but not when the long intervals are ridden all-out",
                "Minutes above 90% of VO₂max in one session, in five comparisons from four studies.")
    W, left, right, rh = 680, 330, 640, 54
    ky = y + 30
    b.append(f'<circle cx="36" cy="{ky}" r="6" fill="{INK}"/>')
    b.append(text(50, ky + 5, "Short or varied intervals", 15.5, INK, "start", "600"))
    b.append(f'<circle cx="290" cy="{ky}" r="6" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
    b.append(text(304, ky + 5, "Longer or steadier intervals", 15.5, INK, "start", "600"))
    top = ky + 46
    base = top + rh * len(rows)
    H = base + 64
    hi = 20.0
    X = lambda v: left + v / hi * (right - left)
    for v in (0, 5, 10, 15, 20):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND if v else MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 48, "Minutes above 90% of VO₂max", 15.5, MID, "middle"))
    halo = 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'
    for i, r in enumerate(rows):
        yy = top + rh * i + rh / 2 - 4
        s_, l_ = float(r["short"]), float(r["long"])
        b.append(text(left - 16, yy - 4, r["label"], 16.5, INK, "end", "600"))
        b.append(text(left - 16, yy + 15, r["note"], 15, MID, "end"))
        b.append(f'<line x1="{X(min(s_, l_)):.1f}" y1="{yy:.1f}" x2="{X(max(s_, l_)):.1f}" y2="{yy:.1f}" stroke="{FAINT}" stroke-width="2"/>')
        b.append(f'<circle cx="{X(l_):.1f}" cy="{yy:.1f}" r="6" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
        b.append(f'<circle cx="{X(s_):.1f}" cy="{yy:.1f}" r="6" fill="{INK}" stroke="#ffffff" stroke-width="1.5"/>')
        hi_v, lo_v = max(s_, l_), min(s_, l_)
        b.append(text(X(hi_v) + 12, yy + 5, f"{hi_v:.1f}", 15.5, INK, "start", "600", halo))
        b.append(text(X(lo_v) - 12, yy + 5, f"{lo_v:.1f}", 15.5, INK, "end", "400", halo))
    return _save("designing-intervals", "time-near-max.svg", W, H, b, "Paired dots of minutes above 90 percent of VO2max: varied 6.8 against steady 4.8; 30/15 18.7 against steady 14.7; 30/15 7.0 against 6 by 5 minutes 3.0 at fixed power and 18.8 against 16.9 all-out; 24 by 30 seconds 3.4 against 4 by 3 minutes 5.5 in runners")


def _bar(x, y_top, w, base, fill, stroke=None, r=4):
    """A vertical bar with a rounded top, anchored to the baseline."""
    h = base - y_top
    if h <= 0:
        return ""
    r = min(r, h, w / 2)
    st = f' stroke="{stroke}" stroke-width="0.75"' if stroke else ""
    return (f'<path d="M{x:.1f},{base:.1f} V{y_top + r:.1f} a{r},{r} 0 0 1 {r},-{r} H{x + w - r:.1f} '
            f'a{r},{r} 0 0 1 {r},{r} V{base:.1f} z" fill="{fill}"{st}/>')


def worked_weeks():
    """Three example weeks (4, 8 and 12 hours), day by day: hard sessions, easy rides and the long ride."""
    rows = _rows("training-week", "worked-weeks.csv")
    b, y = head("The hard sessions stay the same from 4 hours to 12; the easy riding carries the extra hours",
                "Three example weeks, in hours on the bike each day. My construction from the earlier chapters, not a tested programme.")
    W, left, right = 680, 150, 668
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    cw = (right - left) / 7
    ky = y + 28
    keys = [(BAND, MID, "Easy ride"), (MID, None, "Long easy ride"), (INK, None, "Hard session")]
    kx = 30
    for fill, stroke, lab in keys:
        st = f' stroke="{stroke}" stroke-width="0.75"' if stroke else ""
        b.append(f'<rect x="{kx}" y="{ky - 6}" width="12" height="12" fill="{fill}"{st}/>')
        b.append(text(kx + 20, ky + 5, lab, 15.5, INK, "start", "600"))
        kx += 205
    top = ky + 34
    for i, d in enumerate(days):
        b.append(text(left + cw * i + cw / 2, top, d, 15.5, MID, "middle", "600"))
    rh, hmax, barh = 150, 4.0, 96
    y0 = top + 18
    weeks = {}
    for r in rows:
        weeks.setdefault(r["week"], []).append(r)
    for wk in ("4", "8", "12"):
        days_ = weeks[wk]
        base = y0 + rh - 22
        hard_min = {"4 × 8": 32, "5 × 8": 40, "30/15": 19.5}
        work = sum(hard_min.get(d["label"], 0) for d in days_ if d["kind"] == "hard")
        total = sum(float(d["hours"]) for d in days_)
        b.append(text(30, y0 + 40, f"{wk} hours", 18, INK, "start", "600"))
        b.append(text(30, y0 + 62, f"{work:.0f} min of hard work", 15.5, MID))
        b.append(text(30, y0 + 81, f"{work / (total * 60) * 100:.0f}% of the time", 15.5, MID))
        b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{FAINT}" stroke-width="1"/>')
        for i, d in enumerate(days_):
            h = float(d["hours"])
            x = left + cw * i + (cw - 40) / 2
            if h == 0:
                b.append(text(x + 20, base - 6, "rest", 15, FAINT, "middle"))
                continue
            yt = base - h / hmax * barh
            fill, stroke = {"hard": (INK, None), "easy": (BAND, MID), "long": (MID, None)}[d["kind"]]
            b.append(_bar(x, yt, 40, base, fill, stroke))
            lab = f"{h:g} h"
            b.append(text(x + 20, yt - 7, lab, 15, INK, "middle", "600" if d["kind"] == "hard" else "400"))
            if d["label"]:
                b.append(text(x + 20, yt - 25, d["label"], 15, INK, "middle", "600"))
        y0 += rh
    return _save("training-week", "worked-weeks.svg", W, round(y0 + 4), b,
                 "Three example weeks. 4 hours: Tuesday 1 hour hard (4 by 8), Thursday 1 hour easy, Saturday 1.25 hours hard (30/15), Sunday 0.75 easy. 8 hours: Tuesday 1.25 hard, Wednesday 1.5 easy, Thursday 1 easy, Friday 1.25 hard, Saturday 3 long. 12 hours: Tuesday 1.5 hard (5 by 8), Wednesday 2 easy, Thursday 1.5 easy, Friday 1.5 hard, Saturday 4 long, Sunday 1.5 easy. Hard work 52, 52 and 60 minutes.")


def season():
    """Bars: weekly hours across an illustrative twenty-week season, with lighter weeks and a taper."""
    rows = _rows("training-week", "season.csv")
    b, y = head("Hours build and then hold, every fourth week is lighter, and the last two weeks halve the hours",
                "An illustrative season: weekly hours, with a dot for each hard session. Drawn for this book, not data.")
    W, left, right = 680, 70, 664
    top, base = y + 92, y + 322
    hi = 10.0
    Y = lambda v: base - v / hi * (base - top)
    n = len(rows)
    cw = (right - left) / n
    for v in (0, 2, 4, 6, 8, 10):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{INK if v == 0 else BAND}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 5, f"{v}", 15.5, MID, "end"))
    b.append(text(14, top - 18, "Hours", 15.5, MID))
    for i, r in enumerate(rows):
        h, k, ph = float(r["hours"]), int(r["hard_sessions"]), r["phase"]
        x = left + cw * i + 3
        fill, stroke = {"build": (MID, None), "lighter": (BAND, MID), "taper": ("#ffffff", INK)}[ph]
        b.append(_bar(x, Y(h), cw - 6, base, fill, stroke))
        for j in range(k):
            b.append(f'<circle cx="{x + (cw - 6) / 2:.1f}" cy="{Y(h) - 9 - j * 11:.1f}" r="3.5" fill="{INK}"/>')
        if int(r["week"]) in (1, 4, 8, 12, 16, 20):
            b.append(text(x + (cw - 6) / 2, base + 22, r["week"], 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 48, "Week", 15.5, MID, "middle"))
    kx, ky = 30, top - 52
    for fill, stroke, lab in ((MID, None, "Building"), (BAND, MID, "Lighter week"), ("#ffffff", INK, "Taper")):
        st = f' stroke="{stroke}" stroke-width="0.75"' if stroke else ""
        b.append(f'<rect x="{kx}" y="{ky - 6}" width="12" height="12" fill="{fill}"{st}/>')
        b.append(text(kx + 20, ky + 5, lab, 15.5, INK, "start", "600"))
        kx += 150
    b.append(f'<circle cx="{kx + 6}" cy="{ky}" r="3.5" fill="{INK}"/>')
    b.append(text(kx + 20, ky + 5, "Hard session", 15.5, INK, "start", "600"))
    return _save("training-week", "season.svg", W, round(base + 64), b,
                 "Bars of weekly hours over twenty weeks: 6 rising by half an hour a week to 9.5 by week 10, every fourth week about 30 percent lighter with one hard session, and a two-week taper at 5.75 and 4.25 hours with both hard sessions kept.")


def pollock_decline():
    """Lines: VO2max over twenty years in older track athletes, by training group, as % of the start (Pollock 1997)."""
    rows = _rows("special-cases", "pollock1997.csv")
    b, y = head("Older athletes who kept training hard lost the least, but everyone lost",
                "VO₂max as a percentage of each group's value at the start, when their average age was about 50, "
                "measured again 10 and 20 years later.")
    W, left, right = 680, 80, 430
    top, base = y + 40, y + 300
    lo, hi = 50, 100
    Y = lambda v: base - (v - lo) / (hi - lo) * (base - top)
    xs = [left + 10, (left + right) / 2, right - 10]
    for v in (50, 60, 70, 80, 90, 100):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{BAND}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 5, f"{v}%", 15.5, MID, "end"))
    for x, lab, sub in zip(xs, ("Start", "10 years", "20 years"), ("about 50", "about 60", "about 70")):
        b.append(text(x, base + 24, lab, 15.5, INK, "middle", "600"))
        b.append(text(x, base + 43, f"age {sub}", 15, MID, "middle"))
    styles = [(INK, ""), (MID, ""), (MID, ' stroke-dasharray="6 5"')]
    ends = []
    for r, (col, dash) in zip(rows, styles):
        vals = [float(r["t1"]), float(r["t2"]), float(r["t3"])]
        pts = " ".join(f"{x:.1f},{Y(v):.1f}" for x, v in zip(xs, vals))
        b.append(f'<polyline points="{pts}" fill="none" stroke="{col}" stroke-width="2.5"{dash}/>')
        for x, v in zip(xs, vals):
            b.append(f'<circle cx="{x:.1f}" cy="{Y(v):.1f}" r="5" fill="{col}" stroke="#ffffff" stroke-width="1.5"/>')
        ends.append((Y(vals[2]), r, vals))
    for k, (yy, r, vals) in enumerate(ends):
        off = -26 if k == 0 else (14 if k == 1 else 0)
        b.append(text(xs[2] + 16, yy + off, f'{r["group"]} ({r["n"]})', 16.5, INK, "start", "600"))
        b.append(text(xs[2] + 16, yy + off + 19, f'{vals[2]:.0f}% after 20 years', 15.5, MID))
    return _save("special-cases", "pollock-decline.svg", W, round(base + 64), b,
                 "Line chart of VO2max as a percentage of the start over twenty years: remained elite 100, 92, 78; kept training moderately 100, 87, 75; greatly reduced training (two people) 100, 82, 54.")


def who_was_studied():
    """One stacked bar: share of 1,441 sports medicine studies with men only, both, or women only (Ose 2025)."""
    rows = _rows("special-cases", "who-was-studied.csv")
    b, y = head("About one study in five included only men, and one in fourteen only women",
                "Original research in three leading sports medicine journals, 2021 to 2023: 1,441 studies, by who took part.")
    W, left, right = 680, 30, 650
    by = y + 70
    x = left
    fills = {"Men only": INK, "Both": BAND, "Women only": MID}
    for r in rows:
        w = float(r["pct"]) / 100 * (right - left)
        b.append(f'<rect x="{x:.1f}" y="{by}" width="{w - 2:.1f}" height="44" fill="{fills[r["kind"]]}"/>')
        cx = x + w / 2
        if r["kind"] == "Both":
            b.append(text(cx, by + 28, f'Both: {float(r["pct"]):.0f}%', 16.5, INK, "middle", "600"))
        else:
            anchor = "start" if r["kind"] == "Men only" else "end"
            tx = x if anchor == "start" else x + w - 2
            b.append(text(tx, by - 30, r["kind"], 16.5, INK, anchor, "600"))
            b.append(text(tx, by - 11, f'{float(r["pct"]):.1f}% ({r["count"]})', 15.5, MID, anchor))
        x += w
    note, yn = para(left, by + 80, "Of the studies that included women, 5.6% took account of the menstrual cycle in their design. "
                    "The average study's participants were 40% women.", 15.5, MID, 620)
    b += note
    return _save("special-cases", "who-was-studied.svg", W, round(yn), b,
                 "A bar of 1,441 studies: men only 18.6 percent (268), both 74 percent, women only 7.2 percent (103). Of studies including women, 5.6 percent took account of the menstrual cycle.")


def noise():
    """Dots and lines: simulated weekly readings of power at a fixed heart rate, the true trend and a four-week average."""
    rows = _rows("knowing", "noise.csv")
    b, y = head("One week's reading can't show a 5% gain; a four-week average can",
                "A simulated rider whose power at a fixed heart rate truly rises 5% over twelve weeks, measured weekly with a typical error of 3%. "
                "Values are a percentage of the true starting power.")
    W, left, right = 680, 70, 560
    top, base = y + 40, y + 300
    lo, hi = 94, 110
    X = lambda w: left + w / 12 * (right - left)
    Y = lambda v: base - (v - lo) / (hi - lo) * (base - top)
    for v in (94, 98, 102, 106, 110):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{BAND}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 5, f"{v}", 15.5, MID, "end"))
    b.append(f'<line x1="{left}" y1="{Y(100):.1f}" x2="{right}" y2="{Y(100):.1f}" stroke="{FAINT}" stroke-width="1"/>')
    for w in (0, 4, 8, 12):
        b.append(text(X(w), base + 22, f"{w}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 46, "Week", 15.5, MID, "middle"))
    tr = " ".join(f'{X(float(r["week"])):.1f},{Y(float(r["true"])):.1f}' for r in rows)
    b.append(f'<polyline points="{tr}" fill="none" stroke="{MID}" stroke-width="2" stroke-dasharray="6 5"/>')
    av = [r for r in rows if r["avg4"]]
    ap = " ".join(f'{X(float(r["week"])):.1f},{Y(float(r["avg4"])):.1f}' for r in av)
    b.append(f'<polyline points="{ap}" fill="none" stroke="{INK}" stroke-width="2.5"/>')
    for r in rows:
        b.append(f'<circle cx="{X(float(r["week"])):.1f}" cy="{Y(float(r["reading"])):.1f}" r="5" fill="#ffffff" stroke="{INK}" stroke-width="1.75"/>')
    last = rows[-1]
    b.append(text(right + 12, Y(float(last["true"])) - 14, "True power", 15.5, MID, "start", "600"))
    b.append(text(right + 12, Y(float(av[-1]["avg4"])) + 8, "Four-week", 15.5, INK, "start", "600"))
    b.append(text(right + 12, Y(float(av[-1]["avg4"])) + 27, "average", 15.5, INK, "start", "600"))
    b.append(text(right + 12, Y(float(last["reading"])) + 5, "Last reading", 15.5, MID))
    b.append(text(X(0) + 4, Y(109.3), "Each dot is one week's reading", 15.5, MID))
    return _save("knowing", "noise.svg", W, round(base + 62), b,
                 "Simulated weekly readings scattered between about 95 and 109 percent of the starting power, five of them below 100 including the last, while the true power rises steadily to 105 and the four-week average climbs from about 100 to 105.")


def watch_vo2max():
    """Interval plot: bias and limits of agreement of wearable VO2max estimates against the laboratory (Molina-Garcia 2022)."""
    rows = _rows("knowing", "watch-vo2max.csv")
    b, y = head("Watches estimate VO₂max well on average and can be 10 out for one person",
                "Error of consumer wearables' VO₂max estimates against laboratory measurement, in mL/kg/min: "
                "the average error (dot) and the range holding 95% of individual estimates (bar). 14 studies.")
    W, left, right, rh = 680, 250, 650, 72
    lo, hi = -15, 20
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    top = y + 40
    base = top + rh * len(rows)
    for v in (-15, -10, -5, 0, 5, 10, 15, 20):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 6}" x2="{X(v):.1f}" y2="{base}" stroke="{MID if v == 0 else BAND}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v:+d}" if v else "0", 15.5, MID, "middle"))
    b.append(text(X(-15), base + 48, "Too low", 15.5, MID, "start"))
    b.append(text(X(20), base + 48, "Too high", 15.5, MID, "end"))
    for i, r in enumerate(rows):
        yy = top + rh * i + rh / 2
        bias, l, h = float(r["bias"]), float(r["lo"]), float(r["hi"])
        b.append(text(left - 16, yy - 4, r["kind"], 16.5, INK, "end", "600"))
        b.append(text(left - 16, yy + 15, f"average {bias:+.1f}, range {l:.0f} to {h:+.0f}", 15, MID, "end"))
        b.append(f'<rect x="{X(l):.1f}" y="{yy - 7:.1f}" width="{X(h) - X(l):.1f}" height="14" rx="7" fill="{BAND}"/>')
        b.append(f'<circle cx="{X(bias):.1f}" cy="{yy:.1f}" r="7" fill="{INK}" stroke="#ffffff" stroke-width="1.5"/>')
    return _save("knowing", "watch-vo2max.svg", W, round(base + 62), b,
                 "Interval plot. Exercise-based estimates: average error minus 0.1, 95 percent of estimates from minus 10 to plus 10 mL/kg/min. Resting-based estimates: average plus 2.2, from minus 13 to plus 17.")


def banister_uncertainty():
    """Interval plot: four settings of the fitness-fatigue model with 95% confidence intervals, in days (Hellard 2006)."""
    rows = _rows("knowing", "banister.csv")
    b, y = head("The settings behind a fitness and fatigue chart could each be weeks out",
                "Four settings of the fitness–fatigue model fitted to a season of nine elite swimmers, in days: "
                "the estimate (dot) and its 95% confidence interval (bar).")
    W, left, right, rh = 680, 280, 548, 62
    hi = 70
    X = lambda v: left + v / hi * (right - left)
    top = y + 36
    base = top + rh * len(rows)
    for v in range(0, 71, 10):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 6}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
        b.append(text(X(v), base + 22, f"{v}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 46, "Days", 15.5, MID, "middle"))
    for i, r in enumerate(rows):
        yy = top + rh * i + rh / 2
        e, l, h = float(r["est"]), float(r["lo"]), float(r["hi"])
        b.append(text(left - 16, yy - 4, r["label"], 16.5, INK, "end", "600"))
        b.append(text(left - 16, yy + 15, r["note"], 15, MID, "end"))
        b.append(f'<rect x="{X(l):.1f}" y="{yy - 7:.1f}" width="{X(h) - X(l):.1f}" height="14" rx="7" fill="{BAND}"/>')
        b.append(f'<circle cx="{X(e):.1f}" cy="{yy:.1f}" r="7" fill="{INK}" stroke="#ffffff" stroke-width="1.5"/>')
        b.append(text(X(h) + 10, yy + 5, f"{e:.0f} ({l:.0f} to {h:.0f})", 15.5, INK))
    return _save("knowing", "banister-uncertainty.svg", W, round(base + 60), b,
                 "Interval plot in days: fitness fades over 38 (17 to 59), fatigue over 19 (6 to 32), time to recover performance 19 (7 to 35), time to peak after training stops 43 (25 to 61).")


NUMBER_WORDS = {12: "twelve", 13: "thirteen", 14: "fourteen", 15: "fifteen", 16: "sixteen", 17: "seventeen",
                18: "eighteen", 19: "nineteen", 20: "twenty"}


def scorecard():
    """A graded list of claims, the book's verdict on each, the grade of the evidence, and the chapter."""
    rows = _rows("verdict", "scorecard.csv")
    n = NUMBER_WORDS[len(rows)]
    b, y = head(f"The verdict on {n} claims, with the grade of the evidence",
                "A: several randomised trials or a good meta-analysis. B: small, short or single-lab studies. "
                "C: observation, mechanism or opinion.")
    W = 680
    cx, vx, gx, chx = 30, 418, 588, 650
    top = y + 34
    b.append(text(cx, top, "Claim", 15, MID, "start", "600"))
    b.append(text(vx, top, "Verdict", 15, MID, "start", "600"))
    b.append(text(gx + 12, top, "Grade", 15, MID, "middle", "600"))
    b.append(text(chx, top, "Ch.", 15, MID, "middle", "600"))
    yy = top + 14

    def mark(kind, x, y):
        if kind.startswith("Supported"):
            r = 6 if kind == "Supported" else 4.5
            return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{INK}"/>'
        if kind == "Plausible":
            return (f'<circle cx="{x}" cy="{y}" r="6" fill="#ffffff" stroke="{INK}" stroke-width="1.75"/>'
                    f'<path d="M{x},{y - 6} a6,6 0 0 1 0,12 z" fill="{INK}"/>')
        if kind == "Not shown":
            return f'<circle cx="{x}" cy="{y}" r="6" fill="#ffffff" stroke="{INK}" stroke-width="1.75"/>'
        if kind == "Unknown":
            return f'<circle cx="{x}" cy="{y}" r="6" fill="#ffffff" stroke="{MID}" stroke-width="1.5" stroke-dasharray="2.5 2.5"/>'
        return (f'<path d="M{x - 5},{y - 5} L{x + 5},{y + 5} M{x + 5},{y - 5} L{x - 5},{y + 5}" '
                f'stroke="{INK}" stroke-width="2.25" stroke-linecap="round"/>')

    for i, r in enumerate(rows):
        lines, ny = para(cx, yy + 22, r["claim"], 15.5, INK, 370)
        h = ny - (yy + 22) + 14
        if i % 2 == 0:
            b.append(f'<rect x="20" y="{yy + 2:.1f}" width="{W - 40}" height="{h:.1f}" fill="#f4f4f4"/>')
        b += lines
        my = yy + 17
        b.append(mark(r["verdict"], vx + 6, my))
        b.append(text(vx + 20, my + 5, r["verdict"], 15.5, INK, "start", "600"))
        b.append(f'<rect x="{gx}" y="{my - 11}" width="24" height="22" rx="4" fill="#ffffff" stroke="{INK}" stroke-width="1"/>')
        b.append(text(gx + 12, my + 6, r["grade"], 15.5, INK, "middle", "600"))
        b.append(text(chx, my + 5, r["chapter"], 15.5, MID, "middle"))
        yy += h
    return _save("verdict", "scorecard.svg", W, round(yy + 14), b,
                 f"A table of {n} claims with verdicts and grades. " + "; ".join(f'{r["claim"]}: {r["verdict"]}, grade {r["grade"]}' for r in rows))


def session_shapes():
    """Schematic: the shape of five interval sessions over time (work and recovery), with minutes of hard work."""
    b, y = head("Five sessions, drawn to the same time scale",
                "Each after a 10-minute warm-up and with a 10-minute cool-down. Height shows how hard, roughly; the sessions are as listed in this chapter.")
    W, left, right = 680, 178, 590
    tmax = 65.0
    X = lambda t: left + t / tmax * (right - left)
    sess = [
        ("4 × 4 minutes", "3 min easy between", [(4, 3)] * 4, 0.78, "16 min"),
        ("4 × 8 minutes", "2½ min easy between", [(8, 2.5)] * 4, 0.70, "32 min"),
        ("30/15", "3 sets of 13", None, 0.86, "19½ min"),
        ("Threshold, 3 × 12", "3 min easy between", [(12, 3)] * 3, 0.56, "36 min"),
        ("Sprints, 6 × 30 s", "4 min easy between", [(0.5, 4)] * 6, 1.0, "3 min"),
    ]
    rh, amp = 76, 50
    top = y + 34
    b.append(text(right + 12, top - 8, "Hard work", 15, MID, "start", "600"))
    easy = 0.18
    for i, (name, note, reps, lvl, work) in enumerate(sess):
        base = top + rh * i + rh - 14
        seq = [(10, easy)]
        if reps is None:
            for sset in range(3):
                for _ in range(13):
                    seq += [(0.5, lvl), (0.25, easy + 0.05)]
                if sset < 2:
                    seq.append((3, easy))
        else:
            for j, (wk, rec) in enumerate(reps):
                seq.append((wk, lvl))
                if j < len(reps) - 1:
                    seq.append((rec, easy))
        seq.append((10, easy * 0.8))
        t, pts = 0.0, [f"{X(0):.1f},{base:.1f}"]
        for dur, v in seq:
            yv = base - v * amp
            pts.append(f"{X(t):.1f},{yv:.1f}")
            t += dur
            pts.append(f"{X(t):.1f},{yv:.1f}")
        pts.append(f"{X(t):.1f},{base:.1f}")
        b.append(f'<polygon points="{" ".join(pts)}" fill="{MID}" stroke="none"/>')
        b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{FAINT}" stroke-width="1"/>')
        b.append(text(left - 14, base - 24, name, 16.5, INK, "end", "600"))
        b.append(text(left - 14, base - 5, note, 15, MID, "end"))
        b.append(text(right + 12, base - 14, work, 16.5, INK, "start", "600"))
    axis = top + rh * len(sess) + 4
    for v in (0, 10, 20, 30, 40, 50, 60):
        b.append(text(X(v), axis + 16, f"{v}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, axis + 40, "Minutes", 15.5, MID, "middle"))
    return _save("designing-intervals", "session-shapes.svg", W, round(axis + 56), b,
                 "Five session profiles on one time scale: 4 by 4 minutes (16 minutes of hard work), 4 by 8 minutes (32), 30/15 in three sets of 13 (19.5), threshold 3 by 12 minutes (36), sprints 6 by 30 seconds (3), each between a 10-minute warm-up and cool-down.")


def hard_days():
    """Schematic: two hard sessions in a week, with the 48 hours of recovery each needs, at three spacings."""
    b, y = head("With at least 48 hours to recover, a second hard session two days later starts fresh; one a day later doesn't",
                "Two hard sessions in a week (black) and the 48 hours or more of recovery that hard sessions needed in the pooled studies (grey).")
    W, left, right = 680, 210, 664
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    cw = (right - left) / 7
    top = y + 40
    for i, d in enumerate(days):
        b.append(text(left + cw * i + cw / 2, top, d, 15.5, MID, "middle", "600"))
    rows = [("Tuesday and Friday", "72 hours apart", (1, 4), True),
            ("Tuesday and Thursday", "48 hours apart", (1, 3), True),
            ("Tuesday and Wednesday", "24 hours apart", (1, 2), False)]
    rh = 64
    y0 = top + 16
    for name, note, (a, c), ok in rows:
        yy = y0 + rh / 2
        b.append(text(left - 16, yy - 4, name, 16.5, INK, "end", "600"))
        b.append(text(left - 16, yy + 15, note, 15, MID, "end"))
        for i in range(7):
            b.append(f'<rect x="{left + cw * i + 1:.1f}" y="{yy - 14:.1f}" width="{cw - 2:.1f}" height="28" fill="#ffffff" stroke="{BAND}" stroke-width="1"/>')
        for dday in (a, c):
            rx = left + cw * (dday + 0.5)
            b.append(f'<rect x="{rx:.1f}" y="{yy - 9:.1f}" width="{cw * 2:.1f}" height="18" fill="{BAND}"/>')
        for dday in (a, c):
            b.append(f'<rect x="{left + cw * dday + cw * 0.3:.1f}" y="{yy - 12:.1f}" width="{cw * 0.4:.1f}" height="24" rx="3" fill="{INK}"/>')
        if not ok:
            b.append(text(left + cw * (c + 0.5), yy + 34, "starts before the first has recovered", 15.5, INK, "middle", "600"))
        y0 += rh + (14 if not ok else 0)
    note, yn = para(30, y0 + 22, "Schematic, from the review's finding that the heart's nervous control took at least 48 hours to recover after high-intensity sessions, against up to 24 hours after easy ones.", 15.5, MID, 620)
    b += note
    return _save("how-many", "hard-days.svg", W, round(yn), b,
                 "Three weeks with two hard sessions each: Tuesday and Friday, 72 hours apart; Tuesday and Thursday, 48 hours apart; Tuesday and Wednesday, 24 hours apart, where the second session starts inside the first one's 48-hour recovery window.")


def power_duration():
    """Schematic: the power-duration curve, critical power and the three intensity domains (illustrative numbers)."""
    b, y = head("Above critical power every effort has a time limit; below it, the limit is somewhere else",
                "The best power a rider can hold for each duration, drawn for a rider with a critical power of 250 W and "
                "a W′ of 20 kJ. Illustrative numbers, not data.")
    W, left, right = 680, 70, 600
    top, base = y + 40, y + 320
    lo, hi = 150, 500
    tmax = 40.0
    X = lambda t: left + t / tmax * (right - left)
    Y = lambda v: base - (v - lo) / (hi - lo) * (base - top)
    cp, wp, lt1 = 250.0, 20000.0, 190.0
    b.append(f'<rect x="{left}" y="{Y(hi):.1f}" width="{right - left}" height="{Y(cp) - Y(hi):.1f}" fill="#f2f2f2"/>')
    b.append(f'<rect x="{left}" y="{Y(cp):.1f}" width="{right - left}" height="{Y(lt1) - Y(cp):.1f}" fill="#fafafa"/>')
    for v in (150, 200, 250, 300, 350, 400, 450, 500):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{BAND}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 5, f"{v}", 15.5, MID, "end"))
    b.append(text(14, top - 22, "Watts", 15.5, MID))
    for t in (0, 10, 20, 30, 40):
        b.append(text(X(t), base + 22, f"{t}", 15.5, MID, "middle"))
    b.append(text((left + right) / 2, base + 46, "Minutes the effort can be held", 15.5, MID, "middle"))
    pts = []
    t = 1.4
    while t <= tmax:
        pts.append(f"{X(t):.1f},{Y(cp + wp / (t * 60)):.1f}")
        t += 0.2
    b.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{INK}" stroke-width="2.5"/>')
    b.append(f'<line x1="{left}" y1="{Y(cp):.1f}" x2="{right}" y2="{Y(cp):.1f}" stroke="{INK}" stroke-width="1.5" stroke-dasharray="6 5"/>')
    b.append(f'<line x1="{left}" y1="{Y(lt1):.1f}" x2="{right}" y2="{Y(lt1):.1f}" stroke="{MID}" stroke-width="1.25" stroke-dasharray="2 4"/>')
    b.append(text(right + 8, Y(cp) + 5, "Critical", 15.5, INK, "start", "600"))
    b.append(text(right + 8, Y(cp) + 24, "power", 15.5, INK, "start", "600"))
    b.append(text(right + 8, Y(lt1) + 5, "First", 15.5, MID, "start", "600"))
    b.append(text(right + 8, Y(lt1) + 24, "threshold", 15.5, MID, "start", "600"))
    b.append(text(X(39), Y(480), "Severe: the effort ends when W′ runs out", 15.5, INK, "end", "600"))
    b.append(text(X(39), Y(228), "Heavy", 15.5, INK, "end", "600"))
    b.append(text(X(39), Y(172), "Moderate", 15.5, INK, "end", "600"))
    for t in (3, 5, 20):
        v = cp + wp / (t * 60)
        b.append(f'<circle cx="{X(t):.1f}" cy="{Y(v):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="1.5"/>')
        b.append(text(X(t) + 10, Y(v) - 8, f"{t} min: {v:.0f} W", 15.5, INK, "start", "600"))
    return _save("limits", "power-duration.svg", W, round(base + 62), b,
                 "A falling curve of best power against duration that flattens towards a dashed critical power line at 250 W: 361 W for 3 minutes, 317 W for 5, 267 W for 20. Above critical power is the severe domain, between it and the first threshold (190 W, illustrative) the heavy domain, and below that the moderate domain.")


FIGURES = {"ventoux": ventoux, "epo-loop": epo_loop, "oxygen-route": oxygen_route, "cp-decline": cp_decline,
           "carb-dose": carb_dose, "hb-timeline": heat_timeline, "detraining": detraining, "atp-cycle": atp_cycle, "sawtooth": sawtooth, "pain-training": pain_training, "small-trials": small_trials, "carb-curve": carb_curve, "strength-effects": strength_effects,
           "zone-maps": zone_maps, "zone2-markers": zone2_markers,
           "threshold-percent": threshold_percent, "lactate-steps": lactate_steps,
           "mito-efficiency": mito_efficiency, "fatmax-feeding": fatmax_feeding,
           "elite-distributions": elite_distributions, "champions-week": champions_week,
           "dose-response": dose_response, "time-near-max": time_near_max,
           "worked-weeks": worked_weeks, "season": season, "pollock-decline": pollock_decline,
           "who-was-studied": who_was_studied, "noise": noise, "watch-vo2max": watch_vo2max,
           "banister-uncertainty": banister_uncertainty, "scorecard": scorecard,
           "session-shapes": session_shapes, "hard-days": hard_days, "power-duration": power_duration}

if __name__ == "__main__":
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, fn in FIGURES.items():
        if want in name:
            print(fn())
