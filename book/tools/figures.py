#!/usr/bin/env python3
"""Draw the book's figures as SVG, from data files kept beside them.

  python3 book/tools/figures.py            draw every figure
  python3 book/tools/figures.py ventoux    draw the ones whose name contains "ventoux"

Rules (see plan.md and style.md): every chart is drawn from numbers in
research.md, with the source in the caption; nothing is copied from a paper.
Figures must read in black and white, because the paperback prints in black
ink: greys only, and nothing that depends on colour to be understood.

House style: 680 px wide, Helvetica/Arial, 13 px labels, 2 px data lines,
hairline grey axes, labels placed on the chart instead of in a legend.
"""
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = os.path.dirname(HERE)
INK, MID, FAINT, BAND = "#1a1a1a", "#555555", "#bdbdbd", "#e6e6e6"
FONT = 'font-family="Helvetica, Arial, sans-serif"'


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
            f'role="img" aria-label="{title}">\n<rect width="{w}" height="{h}" fill="#ffffff"/>\n'
            + "\n".join(body) + "\n</svg>\n")


def text(x, y, s, size=13, fill=INK, anchor="start", weight="400", style=""):
    return (f'<text x="{x:.1f}" y="{y:.1f}" {FONT} font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" font-weight="{weight}" {style}>{s}</text>')


def ventoux():
    """Forest plot: advantage to the EPO group on each measure in Heuberger 2017."""
    d = os.path.join(BOOK, "chapters", "doping", "figures")
    rows = list(csv.DictReader(l for l in open(os.path.join(d, "ventoux.csv"), encoding="utf-8") if not l.startswith("#")))
    W, left, right, top, rh = 680, 232, 520, 70, 46
    H = top + rh * len(rows) + 62
    lo, hi = -12.0, 10.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    b = []
    # reference band: the 3-5% gain described to the 2015 commission
    b.append(f'<rect x="{X(3):.1f}" y="{top - 12}" width="{X(5) - X(3):.1f}" height="{rh * len(rows) + 8}" fill="{BAND}"/>')
    b.append(text((X(3) + X(5)) / 2, top - 34, "Gain riders described", 12, MID, "middle"))
    b.append(text((X(3) + X(5)) / 2, top - 19, "for small doses: 3 to 5%", 12, MID, "middle"))
    # axis, ticks, zero line
    base = top + rh * len(rows)
    for v in range(-12, 11, 4):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 12}" x2="{X(v):.1f}" y2="{base}" stroke="{FAINT}" stroke-width="{1 if v else 0}"/>')
        b.append(text(X(v), base + 18, f"{v:+d}%" if v else "0", 12, MID, "middle"))
    b.append(f'<line x1="{X(0):.1f}" y1="{top - 12}" x2="{X(0):.1f}" y2="{base}" stroke="{INK}" stroke-width="1"/>')
    b.append(text(X(lo), base + 42, "← placebo group better", 12, MID, "start"))
    b.append(text(X(hi), base + 42, "EPO group better →", 12, MID, "end"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 4
        est, a, c = float(r["estimate"]), float(r["low"]), float(r["high"])
        b.append(text(left - 18, y - 3, r["measure"], 13, INK, "end", "600"))
        b.append(text(left - 18, y + 13, r["setting"], 12, MID, "end"))
        b.append(f'<line x1="{X(a):.1f}" y1="{y:.1f}" x2="{X(c):.1f}" y2="{y:.1f}" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
        b.append(f'<circle cx="{X(est):.1f}" cy="{y:.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        b.append(text(right + 18, y + 4, f"{est:+.1f}%".replace("-", "−"), 13, INK, "start", "600"))
        b.append(text(right + 68, y + 4, f"({a:+.1f} to {c:+.1f})".replace("-", "−"), 12, MID, "start"))
    out = os.path.join(d, "ventoux.svg")
    open(out, "w", encoding="utf-8").write(svg(W, H, b, "Advantage to the EPO group on five measures, with 95% confidence intervals"))
    return out


def epo_loop():
    """Diagram: the feedback loop that controls red cell production, and where the drug enters it."""
    d = os.path.join(BOOK, "chapters", "doping", "figures")
    W, H = 680, 430
    b = ['<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker>'
         '<marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{MID}"/></marker></defs>']

    def box(x, y, w, h, title, lines, fill="#ffffff"):
        o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{INK}" stroke-width="1.5"/>',
             text(x + w / 2, y + 24, title, 14, INK, "middle", "600")]
        for i, l in enumerate(lines):
            o.append(text(x + w / 2, y + 44 + 16 * i, l, 12, MID, "middle"))
        return o

    bw, bh = 200, 84
    kx, ky = 60, 60          # kidney, top left
    ex, ey = 420, 60         # EPO in blood, top right
    mx, my = 420, 280        # marrow, bottom right
    rx_, ry = 60, 280        # red cells, bottom left
    b += box(kx, ky, bw, bh, "Kidney", ["senses how much oxygen", "the blood is delivering"])
    b += box(ex, ey, bw, bh, "EPO in the blood", ["the hormone the kidney", "releases when oxygen is low"])
    b += box(mx, my, bw, bh, "Bone marrow", ["more red cell precursors", "survive and mature"])
    b += box(rx_, ry, bw, bh, "Red cells", ["more haemoglobin,", "more oxygen carried"])

    def arrow(x1, y1, x2, y2, col=INK, mk="ah", dash=""):
        return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{col}" stroke-width="2" marker-end="url(#{mk})" {dash}/>'

    b.append(arrow(kx + bw + 6, ky + bh / 2, ex - 8, ey + bh / 2))
    b.append(text((kx + bw + ex) / 2, ky + bh / 2 - 10, "low oxygen: makes more", 12, INK, "middle"))
    b.append(arrow(ex + bw / 2, ey + bh + 6, mx + bw / 2, my - 8))
    b.append(text(ex + bw / 2 + 12, (ey + bh + my) / 2 + 4, "signal", 12, INK, "start"))
    b.append(arrow(mx - 6, my + bh / 2, rx_ + bw + 8, ry + bh / 2))
    b.append(text((rx_ + bw + mx) / 2, my + bh / 2 - 10, "over days to weeks", 12, INK, "middle"))
    b.append(arrow(rx_ + bw / 2, ry - 6, kx + bw / 2, ky + bh + 8))
    b.append(text(kx + bw / 2 + 12, (ky + bh + ry) / 2 - 4, "more oxygen reaches", 12, INK, "start"))
    b.append(text(kx + bw / 2 + 12, (ky + bh + ry) / 2 + 12, "the kidney: makes less", 12, INK, "start"))
    # outside inputs, drawn in grey with dashed arrows
    dash = 'stroke-dasharray="5 4"'
    b.append(text(kx + bw / 2, 22, "Altitude, blood loss, anaemia", 12, MID, "middle", "400", 'font-style="italic"'))
    b.append(arrow(kx + bw / 2, 30, kx + bw / 2, ky - 8, MID, "ahg", dash))
    b.append(text(ex + bw / 2, 22, "Injected EPO: bypasses the sensor", 12, MID, "middle", "400", 'font-style="italic"'))
    b.append(arrow(ex + bw / 2, 30, ex + bw / 2, ey - 8, MID, "ahg", dash))
    b.append(text(W / 2, H - 18, "Solid arrows: the body's own loop. Dashed arrows: what can push it from outside.", 12, MID, "middle"))
    out = os.path.join(d, "epo-loop.svg")
    open(out, "w", encoding="utf-8").write(svg(W, H, b, "The feedback loop controlling red cell production, and where injected EPO enters it"))
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
    W, H = 680, 270
    b = ['<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker></defs>']
    steps = [("Lungs", ["oxygen crosses", "into the blood"]), ("Blood", ["carried by", "haemoglobin"]),
             ("Heart", ["pumps it out:", "cardiac output"]), ("Capillaries", ["deliver it to", "each fibre"]),
             ("Mitochondria", ["use it to", "make ATP"])]
    bw, bh, gap, x0, y0 = 108, 76, 28, 14, 58
    for i, (name, lines) in enumerate(steps):
        x = x0 + i * (bw + gap)
        b.append(f'<rect x="{x}" y="{y0}" width="{bw}" height="{bh}" rx="8" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>')
        b.append(text(x + bw / 2, y0 + 24, name, 14, INK, "middle", "600"))
        for k, l in enumerate(lines):
            b.append(text(x + bw / 2, y0 + 44 + 15 * k, l, 12, MID, "middle"))
        if i < len(steps) - 1:
            b.append(f'<line x1="{x + bw + 3}" y1="{y0 + bh / 2}" x2="{x + bw + gap - 4}" y2="{y0 + bh / 2}" stroke="{INK}" stroke-width="2" marker-end="url(#ah)"/>')
    b.append(text(x0, 30, "Air", 13, MID, "start", "400", 'font-style="italic"'))
    b.append(f'<line x1="{x0 + 30}" y1="26" x2="{x0 + bw / 2}" y2="{y0 - 8}" stroke="{MID}" stroke-width="1.5" marker-end="url(#ah)"/>')

    def brace(i0, i1, label, subs, y):
        xa, xb = x0 + i0 * (bw + gap), x0 + i1 * (bw + gap) + bw
        b.append(f'<path d="M{xa},{y} v8 H{xb} v-8" fill="none" stroke="{INK}" stroke-width="1.5"/>')
        b.append(text((xa + xb) / 2, y + 28, label, 13, INK, "middle", "600"))
        for k, s in enumerate(subs):
            b.append(text((xa + xb) / 2, y + 45 + 15 * k, s, 12, MID, "middle"))

    brace(0, 2, "Delivery: mostly sets VO₂max", ["how much oxygen reaches", "the muscle each minute"], y0 + bh + 14)
    brace(3, 4, "The muscle", ["mostly sets the fraction", "of VO₂max you can sustain"], y0 + bh + 14)
    b.append(text(W / 2, H - 16, "Efficiency is the third factor: how much of the energy released ends up as power at the pedals.", 12, MID, "middle"))
    return _save("limits", "oxygen-route.svg", W, H, b, "Oxygen's route from the air to the muscle, and the factors that limit endurance")


def cp_decline():
    """Line chart: critical power and W' as a percentage of fresh, over two hours (Clark 2019a)."""
    rows = _rows("durability", "clark2019a.csv")
    W, H, left, right, top, base = 680, 360, 70, 500, 40, 290
    X = lambda m: left + m / 120 * (right - left)
    Y = lambda p: base - (p - 70) / (110 - 70) * (base - top)
    b = []
    for p in (70, 80, 90, 100, 110):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 100 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 4, f"{p}%", 12, MID, "end"))
    for m in (0, 40, 80, 120):
        b.append(text(X(m), base + 20, "fresh" if m == 0 else f"{m} min", 12, MID, "middle"))
    b.append(text((left + right) / 2, base + 44, "Time ridden at 164 W before the test", 12, MID, "middle"))
    b.append(text(left - 52, top - 14, "Per cent of the fresh value", 12, MID, "start"))
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
    b.append(text(right + 14, Y(cp[-1][1]) - 2, "Critical power", 13, INK, "start", "600"))
    b.append(text(right + 14, Y(cp[-1][1]) + 14, f"236 W, down 9%", 12, MID, "start"))
    b.append(text(right + 14, Y(wp[-1][1]) - 2, "W′, the reserve above it", 13, INK, "start", "600"))
    b.append(text(right + 14, Y(wp[-1][1]) + 14, "13.8 kJ, down 23%", 12, MID, "start"))
    return _save("durability", "cp-decline.svg", W, H, b, "Critical power and W prime as a percentage of their fresh values over two hours of riding")


def carb_dose():
    """Bar chart: fall in critical power after three hours, by carbohydrate intake (Norte 2026)."""
    rows = _rows("durability", "norte2026.csv")
    W, left, right, top, rh = 680, 240, 520, 46, 50
    H = top + rh * len(rows) + 56
    X = lambda v: left + v / 16 * (right - left)
    b, base = [], top + rh * len(rows)
    for v in (0, 4, 8, 12, 16):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{INK if v == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(X(v), base + 18, f"{v}%", 12, MID, "middle"))
    b.append(text((left + right) / 2, base + 42, "Fall in critical power after three hours (fresh: 277 W)", 12, MID, "middle"))
    for i, r in enumerate(rows):
        y, v = top + rh * i + 8, float(r["fall_pct"])
        b.append(text(left - 14, y + 16, r["condition"], 13, INK, "end"))
        b.append(f'<path d="M{X(0):.1f},{y} H{X(v) - 4:.1f} a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 H{X(0):.1f} z" fill="{MID}"/>')
        b.append(text(X(v) + 10, y + 12, f"{v:.1f}%", 13, INK, "start", "600"))
        b.append(text(X(v) + 10, y + 27, f"{r['cp_w']} W left", 12, MID, "start"))
    return _save("durability", "carb-dose.svg", W, H, b, "Fall in critical power after three hours of riding, by carbohydrate intake")


def heat_timeline():
    """Line chart: haemoglobin mass during and after five weeks of heat training (Cubel 2024)."""
    rows = _rows("heat-training", "cubel2024.csv")
    W, H, left, right, top, base = 680, 340, 70, 560, 56, 262
    X = lambda wk: left + wk / 7 * (right - left)
    Y = lambda p: base - p / 5 * (base - top)
    b = [f'<rect x="{X(0):.1f}" y="{top}" width="{X(5) - X(0):.1f}" height="{base - top}" fill="{BAND}"/>',
         text((X(0) + X(5)) / 2, top - 26, "Heat sessions: six hours a week", 12, MID, "middle"),
         text((X(5) + X(7)) / 2, top - 26, "Stopped", 12, MID, "middle"),
         f'<path d="M{X(0):.1f},{top - 16} v6 H{X(5) - 2:.1f} v-6" fill="none" stroke="{MID}" stroke-width="1"/>',
         f'<path d="M{X(5) + 2:.1f},{top - 16} v6 H{X(7):.1f} v-6" fill="none" stroke="{MID}" stroke-width="1"/>']
    for p in range(0, 6):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 4, f"+{p}%" if p else "0", 12, MID, "end"))
    for wk in (0, 3, 5, 7):
        b.append(text(X(wk), base + 20, "start" if wk == 0 else f"week {wk}", 12, MID, "middle"))
    b.append(text((left + right) / 2, base + 46, "Change in total haemoglobin mass", 12, MID, "middle"))
    s = [(float(r["week"]), float(r["change_pct"])) for r in rows]
    b.append(f'<polyline points="{" ".join(f"{X(a):.1f},{Y(c):.1f}" for a, c in s)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for a, c in s:
        b.append(f'<circle cx="{X(a):.1f}" cy="{Y(c):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(X(3) - 10, Y(3) - 12, "+3%", 13, INK, "end", "600"))
    b.append(text(X(5), Y(4) - 14, "+4%", 13, INK, "middle", "600"))
    b.append(text(X(7) + 12, Y(0) - 10, "back to", 12, MID, "start"))
    b.append(text(X(7) + 12, Y(0) + 6, "the start", 12, MID, "start"))
    return _save("heat-training", "hb-timeline.svg", W, H, b, "Haemoglobin mass during five weeks of heat training and two weeks after stopping")


def detraining():
    """Line chart: VO2max after stopping training (Coyle 1984)."""
    rows = _rows("adaptation", "coyle1984.csv")
    W, H, left, right, top, base = 680, 330, 70, 540, 40, 250
    X = lambda d: left + d / 84 * (right - left)
    Y = lambda p: top + (-p) / 20 * (base - top)
    b = []
    for p in (0, -5, -10, -15, -20):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 4, f"−{-p}%" if p else "0", 12, MID, "end"))
    for d in (0, 21, 56, 84):
        b.append(text(X(d), base + 20, "last session" if d == 0 else f"day {d}", 12, MID, "middle"))
    b.append(text((left + right) / 2, base + 46, "Change in VO₂max after training stopped", 12, MID, "middle"))
    s = [(float(r["day"]), float(r["change_pct"])) for r in rows]
    b.append(f'<polyline points="{" ".join(f"{X(a):.1f},{Y(c):.1f}" for a, c in s)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for a, c in s:
        b.append(f'<circle cx="{X(a):.1f}" cy="{Y(c):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(X(21) + 12, Y(-7) - 8, "−7%", 13, INK, "start", "600"))
    b.append(text(X(56), Y(-16) + 24, "−16%", 13, INK, "middle", "600"))
    b.append(text(X(84) + 12, Y(-16) - 4, "still above", 12, MID, "start"))
    b.append(text(X(84) + 12, Y(-16) + 12, "people who had", 12, MID, "start"))
    b.append(text(X(84) + 12, Y(-16) + 28, "never trained", 12, MID, "start"))
    return _save("adaptation", "detraining.svg", W, H, b, "VO2max over 84 days after stopping endurance training")


def atp_cycle():
    """Diagram: ATP spent and rebuilt, and the AMP side branch that AMPK reads."""
    W, H = 680, 410
    b = ['<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker>'
         '<marker id="ahg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
         f'<path d="M0,0 L10,5 L0,10 z" fill="{MID}"/></marker></defs>']

    def box(x, y, w, h, title, lines):
        o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>',
             text(x + w / 2, y + 26, title, 15, INK, "middle", "600")]
        for i, l in enumerate(lines):
            o.append(text(x + w / 2, y + 46 + 16 * i, l, 12, MID, "middle"))
        return o

    def arrow(x1, y1, x2, y2, col=INK, mk="ah", dash=""):
        return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{col}" stroke-width="2" marker-end="url(#{mk})" {dash}/>'

    bw, bh = 180, 96
    ax, ay = 40, 60          # ATP, top left
    dx, dy = 460, 60         # ADP, top right
    mx, my = 460, 270        # AMP, bottom right
    kx, ky = 40, 270         # AMPK, bottom left
    b += box(ax, ay, bw, bh, "ATP", ["three phosphates", "carries the energy"])
    b += box(dx, dy, bw, bh, "ADP", ["two phosphates", "what is left when ATP is spent"])
    b += box(mx, my, bw, bh, "AMP", ["one phosphate", "rises when ADP builds up"])
    b += box(kx, ky, bw, bh, "AMPK", ["the sensor: switches on when", "AMP rises against ATP"])
    mid = (ax + bw + dx) / 2
    b.append(arrow(ax + bw + 6, ay + 28, dx - 8, ay + 28))
    b.append(text(mid, ay + 4, "Contraction splits off a phosphate", 12, INK, "middle"))
    b.append(text(mid, ay + 20, "and releases the energy", 12, INK, "middle"))
    b.append(arrow(dx - 6, ay + 68, ax + bw + 8, ay + 68))
    b.append(text(mid, ay + 88, "Mitochondria rebuild it,", 12, INK, "middle"))
    b.append(text(mid, ay + 104, "using oxygen and fuel", 12, INK, "middle"))
    dash = 'stroke-dasharray="5 4"'
    b.append(arrow(dx + bw / 2, dy + bh + 6, mx + bw / 2, my - 8, MID, "ahg", dash))
    b.append(text(dx + bw / 2 - 12, (dy + bh + my) / 2 - 4, "when demand", 12, MID, "end"))
    b.append(text(dx + bw / 2 - 12, (dy + bh + my) / 2 + 12, "outruns supply", 12, MID, "end"))
    b.append(arrow(mx - 6, my + bh / 2, kx + bw + 8, ky + bh / 2, MID, "ahg", dash))
    b.append(text(mid, my + bh / 2 - 10, "read as a fuel gauge", 12, MID, "middle"))
    b.append(text(W / 2, H - 14, "Solid arrows: the cycle that runs all the time. Dashed arrows: what happens when it falls behind.", 12, MID, "middle"))
    return _save("adaptation", "atp-cycle.svg", W, H, b, "ATP is spent to ADP and rebuilt; when ADP builds up, AMP rises and AMPK switches on")


def sawtooth():
    """Two-panel time series: PGC-1a mRNA bursts and protein build-up over seven sessions (Perry 2010)."""
    W, H, left, right = 680, 520, 96, 640
    step = (right - left - 30) / 6.6
    xs = lambda i: left + 14 + (i - 1) * step          # start of session i
    b = []
    # ---- panel A: mRNA, fold of the starting level
    at, ab = 64, 204
    YA = lambda f: ab - (f - 1) / 10 * (ab - at)
    b.append(text(left, at - 34, "PGC-1α messenger RNA", 14, INK, "start", "600"))
    b.append(text(left, at - 17, "a burst after every session, gone within a day", 12, MID, "start"))
    for f in (1, 5, 10):
        b.append(f'<line x1="{left}" y1="{YA(f):.1f}" x2="{right}" y2="{YA(f):.1f}" stroke="{INK if f == 1 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, YA(f) + 4, "start" if f == 1 else f"{f}×", 12, MID, "end"))
    peaks = {1: 10.8, 2: 9.3, 3: 8.1, 4: 7.1, 5: 6.2, 6: 5.5, 7: 4.9}   # only the first is a reported value
    for i, pk in peaks.items():
        meas = i in (1, 3, 5, 7)
        col, dash = (INK, "") if meas else (FAINT, 'stroke-dasharray="4 3"')
        x0 = xs(i)
        b.append(f'<polyline points="{x0:.1f},{YA(1):.1f} {x0 + step * 0.16:.1f},{YA(pk):.1f} {x0 + step * 0.55:.1f},{YA(1):.1f}" '
                 f'fill="none" stroke="{col}" stroke-width="2" stroke-linejoin="round" {dash}/>')
    b.append(text(xs(1) + step * 0.16 + 14, YA(10.8) + 5, "more than 10×, four hours after session 1", 12, INK, "start", "600"))
    b.append(text(xs(5) + step * 0.3, YA(8.6), "smaller each time", 12, MID, "start"))
    # ---- panel B: protein, per cent above the start
    bt, bb = 300, 420
    YB = lambda p: bb - p / 50 * (bb - bt)
    b.append(text(left, bt - 34, "PGC-1α protein", 14, INK, "start", "600"))
    b.append(text(left, bt - 17, "rises after the first session and does not fall back", 12, MID, "start"))
    for p in (0, 25, 50):
        b.append(f'<line x1="{left}" y1="{YB(p):.1f}" x2="{right}" y2="{YB(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, YB(p) + 4, "start" if p == 0 else f"+{p}%", 12, MID, "end"))
    pts = [(left, 0), (xs(1) + step * 0.55, 23), (xs(5) + step * 0.55, 42), (xs(7) + step * 0.55, 42)]
    b.append(f'<polyline points="{" ".join(f"{x:.1f},{YB(v):.1f}" for x, v in pts)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round" stroke-dasharray="6 4"/>')
    for x, v in pts[1:]:
        b.append(f'<circle cx="{x:.1f}" cy="{YB(v):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(pts[1][0] + 10, YB(23) + 16, "+23%", 13, INK, "start", "600"))
    b.append(text(pts[2][0], YB(42) - 12, "+42%", 13, INK, "middle", "600"))
    b.append(text(pts[3][0], YB(42) - 12, "+42%", 13, INK, "middle", "600"))
    # ---- shared session axis and the later arrivals
    for i in range(1, 8):
        for y in (ab, bb):
            b.append(f'<line x1="{xs(i):.1f}" y1="{y}" x2="{xs(i):.1f}" y2="{y + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(xs(i), ab + 20, str(i), 12, MID, "middle"))
        b.append(text(xs(i), bb + 20, str(i), 12, MID, "middle"))
    b.append(text(left - 10, ab + 20, "session", 12, MID, "end"))
    b.append(text(left - 10, bb + 20, "session", 12, MID, "end"))
    for i, l1, l2 in ((3, "citrate synthase", "activity first up: +17%"), (5, "COX-IV protein", "first up: +20%")):
        x = xs(i) + step * 0.3
        b.append(f'<path d="M{x:.1f},{bb + 30} l-5,9 h10 z" fill="{INK}"/>')
        b.append(text(x, bb + 56, l1, 12, INK, "middle"))
        b.append(text(x, bb + 72, l2, 12, INK, "middle"))
    return _save("adaptation", "sawtooth.svg", W, H, b, "PGC-1 alpha messenger RNA bursts and protein build-up across seven training sessions")


def pain_training():
    """Bar chart: change in pain tolerance and time to exhaustion by training group (O'Leary 2017)."""
    rows = _rows("effort-and-pain", "oleary2017.csv")
    W, left, right, top, rh, gap = 680, 250, 560, 40, 40, 26
    lo, hi = -20.0, 160.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    n_groups = len({r["measure"] for r in rows})
    base = top + rh * len(rows) + gap * (n_groups - 1) + 24 * n_groups
    b = []
    for v in (0, 50, 100, 150):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{INK if v == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(X(v), base + 18, f"+{v}%" if v else "0", 12, MID, "middle"))
    b.append(text((X(0) + right) / 2, base + 42, "Change after six weeks of training", 12, MID, "middle"))
    y, last = top, None
    for r in rows:
        if last is not None and r["measure"] != last:
            y += gap
        if r["measure"] != last:
            b.append(text(left - 44, y + 12, r["measure"], 13, INK, "end", "600"))
            y += 24
        last = r["measure"]
        v = float(r["change_pct"])
        hard = r["group"].startswith("Hard")
        b.append(text(left - 44, y + 16, r["group"], 12, INK if hard else MID, "end"))
        x0, x1 = sorted((X(0), X(v)))
        b.append(f'<rect x="{x0:.1f}" y="{y + 4}" width="{max(x1 - x0, 1.5):.1f}" height="20" rx="3" fill="{INK if hard else FAINT}"/>')
        lab = (f"+{v:.0f}%" if v > 0 else f"−{-v:.0f}%")
        b.append(text(X(max(v, 0)) + 10, y + 19, lab, 13, INK, "start", "600"))
        y += rh
    return _save("effort-and-pain", "pain-training.svg", W, base + 56, b, "Change in pain tolerance and time to exhaustion after six weeks of hard intervals or steady riding")


def small_trials():
    """Two histograms on one scale: results of 20,000 simulated trials with 10 and with 50 people per group."""
    rows = _rows("reading-research", "small-trials.csv")
    W, left, right = 680, 40, 650
    lo, hi = -6, 13
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    bw = X(0.5) - X(0)
    mx = 0.21                           # one vertical scale for both panels, so bar heights compare directly
    b = [text(left, 26, "Small trials that reach significance overstate the effect", 14, INK, "start", "600"),
         text(left, 45, "Results of 20,000 simulated trials of a method whose real advantage is 3 points.", 12, MID, "start")]
    # (n, top, base, title, subtitle, wrong-direction note, note on the significant trials, their mean)
    panels = [(10, 132, 302, "10 people in each group", "25% of trials reached statistical significance (black). 75% did not (grey).",
               "9% favoured the wrong method", "significant trials averaged +5.7", 5.7),
              (50, 424, 594, "50 people in each group", "84% of trials reached statistical significance (black). 16% did not (grey).",
               "0.1% favoured the wrong method", "significant trials averaged +3.3", 3.3)]
    for n, top, base, title, sub, wrong, sigtxt, sigmean in panels:
        sel = [r for r in rows if int(r["n"]) == n]
        Y = lambda sh: base - sh / mx * (base - top)
        b.append(text(left, top - 52, title, 14, INK, "start", "600"))
        b.append(text(left, top - 34, sub, 12, MID, "start"))
        b.append(f'<rect x="{X(lo):.1f}" y="{top}" width="{X(0) - X(lo):.1f}" height="{base - top}" fill="#f3f3f3"/>')
        for r in sel:
            x, sh, sg = X(float(r["lo"])), float(r["share"]), float(r["sig_share"])
            if sh > 0.0005:
                b.append(f'<rect x="{x + 0.5:.1f}" y="{Y(sh):.1f}" width="{bw - 1:.1f}" height="{base - Y(sh):.1f}" fill="{FAINT}"/>')
            if sg > 0.0005:
                b.append(f'<rect x="{x + 0.5:.1f}" y="{Y(sg):.1f}" width="{bw - 1:.1f}" height="{base - Y(sg):.1f}" fill="{INK}"/>')
        b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{INK}" stroke-width="1"/>')
        b.append(f'<line x1="{X(3):.1f}" y1="{top}" x2="{X(3):.1f}" y2="{base}" stroke="{INK}" stroke-width="1.5" stroke-dasharray="5 4"/>')
        b.append(text(X(3), top - 7, "true advantage +3", 12, INK, "middle"))
        b.append(text(X(lo) + 6, top + 16, wrong, 12, MID, "start"))
        b.append(text(X(lo) + 6, top + 32, "(shaded area)", 11, MID, "start"))
        b.append(text(right, top + 16, sigtxt, 12, INK, "end", "600"))
        if n == 10:
            b.append(f'<line x1="{X(sigmean):.1f}" y1="{top + 24}" x2="{X(sigmean):.1f}" y2="{base - 40}" stroke="{INK}" stroke-width="1"/>')
            b.append(f'<path d="M{X(sigmean) - 4:.1f},{base - 46} L{X(sigmean) + 4:.1f},{base - 46} L{X(sigmean):.1f},{base - 38} Z" fill="{INK}"/>')
        for v in range(-6, 13, 3):
            b.append(text(X(v), base + 18, ("−" + str(-v)) if v < 0 else (f"+{v}" if v else "0"), 12, MID, "middle"))
    b.append(text((left + right) / 2, 594 + 42, "Advantage the trial measured for the better method (points)", 12, MID, "middle"))
    return _save("reading-research", "small-trials.svg", W, 654, b, "Results of 20,000 simulated trials of the same true effect, with 10 and with 50 people per group")


def carb_curve():
    """Line chart: time-trial gain against carbohydrate dose (Smith 2013)."""
    rows = _rows("fuelling", "smith2013.csv")
    W, H, left, right, top, base = 680, 380, 70, 600, 90, 290
    X = lambda d: left + d / 120 * (right - left)
    Y = lambda p: base - p / 5 * (base - top)
    b = [text(left - 40, 28, "Most of the gain from carbohydrate arrives by 50 grams an hour", 14, INK, "start", "600"),
         text(left - 40, 47, "Improvement in a 20 km time trial after a two-hour ride, against a placebo drink. 51 cyclists.", 12, MID, "start")]
    b.append(f'<rect x="{X(78):.1f}" y="{top}" width="{X(120) - X(78):.1f}" height="{base - top}" fill="#f3f3f3"/>')
    for p in range(0, 6):
        b.append(f'<line x1="{left}" y1="{Y(p):.1f}" x2="{right}" y2="{Y(p):.1f}" stroke="{INK if p == 0 else FAINT}" stroke-width="1"/>')
        b.append(text(left - 10, Y(p) + 4, f"+{p}%" if p else "0", 12, MID, "end"))
    for d in range(0, 121, 30):
        b.append(text(X(d), base + 20, str(d), 12, MID, "middle"))
    b.append(text((left + right) / 2, base + 46, "Carbohydrate drunk during the ride (grams an hour)", 12, MID, "middle"))
    s = [(float(r["dose_g_h"]), float(r["gain_pct"])) for r in rows]
    b.append(f'<polyline points="{" ".join(f"{X(a):.1f},{Y(c):.1f}" for a, c in s)}" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    for a, c in s[1:]:
        b.append(f'<circle cx="{X(a):.1f}" cy="{Y(c):.1f}" r="5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
    b.append(text(X(48) - 10, Y(4.0) - 12, "+4.0% at 48", 13, INK, "end", "600"))
    b.append(text(X(78), Y(4.7) - 14, "+4.7% at 78, the peak", 13, INK, "middle", "600"))
    b.append(text(X(99), Y(2.6), "above 78 the", 12, MID, "middle"))
    b.append(text(X(99), Y(2.6) + 16, "benefit shrank", 12, MID, "middle"))
    b.append(text(X(99), Y(2.6) + 32, "(sizes not reported", 11, MID, "middle"))
    b.append(text(X(99), Y(2.6) + 46, "in the abstract)", 11, MID, "middle"))
    return _save("fuelling", "carb-curve.svg", W, H, b, "Time-trial improvement against carbohydrate dose, from Smith 2013")


def strength_effects():
    """Interval plot: pooled effects of heavy strength training in cyclists (Llanos-Lagos 2026)."""
    rows = _rows("strength", "llanos2026.csv")
    W, left, right, top, rh = 680, 200, 520, 96, 44
    H = top + rh * len(rows) + 62
    lo, hi = -0.6, 1.2
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows)
    b = [text(30, 28, "Lifting makes cyclists faster without raising VO₂max or threshold", 14, INK, "start", "600"),
         text(30, 47, "Pooled effect of adding heavy strength training, from 17 controlled studies of cyclists.", 12, MID, "start"),
         text(30, 63, "Lines are 95% confidence intervals; a line that crosses zero means no clear effect.", 12, MID, "start")]
    for v in (-0.5, 0.5, 1.0):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{FAINT}" stroke-width="1"/>')
        b.append(text(X(v), base + 18, f"{v:+.1f}".replace("-", "−"), 12, MID, "middle"))
    b.append(f'<line x1="{X(0):.1f}" y1="{top - 8}" x2="{X(0):.1f}" y2="{base}" stroke="{INK}" stroke-width="1"/>')
    b.append(text(X(0), base + 18, "0", 12, MID, "middle"))
    b.append(text((left + right) / 2, base + 42, "Effect size (standard deviations; 0.2 is small, 0.5 moderate)", 12, MID, "middle"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 4
        est, a, c = float(r["estimate"]), float(r["low"]), float(r["high"])
        b.append(text(left - 18, y - 3, r["measure"], 13, INK, "end", "600"))
        b.append(text(left - 18, y + 13, r["setting"], 12, MID, "end"))
        b.append(f'<line x1="{X(a):.1f}" y1="{y:.1f}" x2="{X(c):.1f}" y2="{y:.1f}" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
        b.append(f'<circle cx="{X(est):.1f}" cy="{y:.1f}" r="5.5" fill="{INK if a > 0 else "#ffffff"}" stroke="{INK}" stroke-width="2"/>')
        b.append(text(right + 18, y + 4, f"{est:+.2f}".replace("-", "−"), 13, INK, "start", "600"))
        b.append(text(right + 66, y + 4, "clear" if a > 0 else "not clear", 12, MID, "start"))
    return _save("strength", "strength-effects.svg", W, H, b, "Pooled effects of heavy strength training on six measures in cyclists, from Llanos-Lagos 2026")


def zone_maps():
    """Schematic: a lactate curve, the two thresholds, and three ways of dividing the intensity range."""
    W, H = 680, 440
    left, right, top, base = 60, 640, 96, 250
    t1, t2 = left + 0.45 * (right - left), left + 0.72 * (right - left)
    b = [text(30, 28, "Zone 2 is the middle of one map and the easy end of another", 14, INK, "start", "600"),
         text(30, 47, "Blood lactate in a test of rising power (a sketch, not data), the two thresholds,", 12, MID, "start"),
         text(30, 63, "and three ways of dividing the range. Both cells called Zone 2 are shaded.", 12, MID, "start")]
    b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    b.append(f'<line x1="{left}" y1="{top}" x2="{left}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    b.append(text(left - 12, (top + base) / 2, "Blood lactate", 12, MID, "middle", style=f'transform="rotate(-90 {left - 12} {(top + base) / 2})"'))
    b.append(text(right, base + 18, "Power →", 12, MID, "end"))
    b.append(text(left, base + 18, "Easy", 12, MID, "start"))
    y0 = base - 22
    b.append(f'<path d="M{left},{y0} L{t1 - 40:.1f},{y0} Q{t1:.1f},{y0} {t1 + 40:.1f},{y0 - 12} '
             f'C{t2 - 40:.1f},{y0 - 34} {t2 + 20:.1f},{y0 - 60} {t2 + 60:.1f},{y0 - 105} L{t2 + 80:.1f},{y0 - 128}" '
             f'fill="none" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
    for x, lab in ((t1, "First threshold"), (t2, "Second threshold")):
        b.append(f'<line x1="{x:.1f}" y1="{top + 14}" x2="{x:.1f}" y2="{base}" stroke="{MID}" stroke-width="1" stroke-dasharray="4 4"/>')
        b.append(text(x, top + 6, lab, 12, INK, "middle", "600"))
    rows = [("What the body does: intensity domains", [(left, t1, "Moderate", 0), (t1, t2, "Heavy", 0), (t2, right, "Severe", 0)]),
            ("Three-zone model, used in most research", [(left, t1, "Zone 1", 0), (t1, t2, "Zone 2", 1), (t2, right, "Zone 3", 0)]),
            ("Five-zone model, used by the Norwegian federation and most apps",
             [(left, (left + t1) / 2, "Zone 1", 0), ((left + t1) / 2, t1, "Zone 2", 1), (t1, t2, "Zone 3", 0),
              (t2, (t2 + right) / 2, "Zone 4", 0), ((t2 + right) / 2, right, "Zone 5", 0)])]
    y = base + 44
    for label, cells in rows:
        b.append(text(left, y, label, 12, MID, "start"))
        for a, c, name, hit in cells:
            b.append(f'<rect x="{a + 1:.1f}" y="{y + 7}" width="{c - a - 2:.1f}" height="26" fill="{BAND if hit else "#ffffff"}" stroke="{INK if hit else FAINT}" stroke-width="{1.5 if hit else 1}"/>')
            b.append(text((a + c) / 2, y + 25, name, 12.5, INK, "middle", "600" if hit else "400"))
        y += 56
    return _save("intensity", "zone-maps.svg", W, H, b, "Sketch of a lactate curve with two thresholds, and the three-zone and five-zone models beneath it")


def zone2_markers():
    """Dot plot: mean power at nine markers of Zone 2 in the same 50 cyclists (Meixner 2025)."""
    rows = _rows("intensity", "meixner2025.csv")
    W, left, right, top, rh = 680, 262, 560, 96, 38
    H = top + rh * len(rows) + 58
    lo, hi = 100.0, 250.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows)
    b = [text(30, 28, "Nine markers of Zone 2 span about 100 watts in the same riders", 14, INK, "start", "600"),
         text(30, 47, "Average power at each marker in 50 trained cyclists tested in one laboratory,", 12, MID, "start"),
         text(30, 63, "with the heart rate at that power as a percentage of maximum.", 12, MID, "start")]
    b.append(f'<line x1="{X(lo):.1f}" y1="{base}" x2="{X(hi):.1f}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (100, 150, 200, 250):
        b.append(f'<line x1="{X(v):.1f}" y1="{base}" x2="{X(v):.1f}" y2="{base + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 20, f"{v} W", 12, MID, "middle"))
    b.append(text(right + 86, top - 14, "heart rate", 12, MID, "end"))
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 4
        p = float(r["power"])
        b.append(text(left - 16, y + (-3 if r["note"] else 4), r["marker"], 13, INK, "end", "600"))
        if r["note"]:
            b.append(text(left - 16, y + 12, r["note"], 11.5, MID, "end"))
        b.append(f'<line x1="{X(lo):.1f}" y1="{y:.1f}" x2="{X(p):.1f}" y2="{y:.1f}" stroke="{FAINT}" stroke-width="1"/>')
        b.append(f'<circle cx="{X(p):.1f}" cy="{y:.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        b.append(text(X(p) + 12, y + 4, f"{p:.0f} W", 13, INK, "start", "600"))
        b.append(text(right + 86, y + 4, f'{r["hr"]}%', 12, MID, "end"))
    return _save("intensity", "zone2-markers.svg", W, H, b, "Average power at nine markers of Zone 2 in 50 trained cyclists, from Meixner 2025")

def threshold_percent():
    """Four range bars on one scale: two rules for Zone 2, and where the first lactate threshold was measured, as % of maximum heart rate."""
    rows = _rows("finding-zones", "threshold-percent.csv")
    W, left, right, top, rh, gap = 680, 250, 630, 122, 44, 46
    lo, hi = 50.0, 95.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows) + gap + 6
    H = base + 76
    b = [text(30, 28, "No fixed percentage of maximum heart rate finds the first threshold", 14, INK, "start", "600"),
         text(30, 47, "Every bar is a range of heart rates, as a percentage of the person’s own maximum.", 12, MID, "start"),
         text(30, 63, "The first threshold is the top of Zone 2.", 12, MID, "start")]
    for v in (50, 60, 70, 80, 90):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 30}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
    b.append(f'<line x1="{X(lo):.1f}" y1="{base}" x2="{X(hi):.1f}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (50, 60, 70, 80, 90):
        b.append(f'<line x1="{X(v):.1f}" y1="{base}" x2="{X(v):.1f}" y2="{base + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 20, f"{v}%", 12, MID, "middle"))
    b.append(text((X(lo) + X(hi)) / 2, base + 40, "Percentage of maximum heart rate", 12, MID, "middle"))
    heads = {"rule": "Where two rules put Zone 2", "measured": "Where the first lactate threshold was measured"}
    y0, seen = top, None
    for r in rows:
        if r["kind"] != seen:
            if seen is not None:
                y0 += gap
            b.append(text(30, y0 - 12, heads[r["kind"]], 12.5, MID, "start", "600", 'paint-order="stroke" stroke="#ffffff" stroke-width="6"'))
            seen = r["kind"]
        y = y0 + rh / 2
        a, c = float(r["lo"]), float(r["hi"])
        b.append(text(left - 44, y - 2, r["label"], 13, INK, "end", "600"))
        b.append(text(left - 44, y + 13, r["note"], 11.5, MID, "end"))
        if r["kind"] == "rule":
            b.append(f'<rect x="{X(a):.1f}" y="{y - 8:.1f}" width="{X(c) - X(a):.1f}" height="16" fill="#ffffff" stroke="{INK}" stroke-width="1.5"/>')
        else:
            b.append(f'<rect x="{X(a):.1f}" y="{y - 8:.1f}" width="{X(c) - X(a):.1f}" height="16" fill="{INK}"/>')
        b.append(text(X(a) - 7, y + 4, f"{a:.0f}%", 12, INK, "end", "600", 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'))
        b.append(text(X(c) + 7, y + 4, f"{c:.0f}%", 12, INK, "start", "600", 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'))
        y0 += rh
    b.append(text(30, base + 64, "A rule fits a rider only if its upper end, 70% or 82%, is where that rider’s threshold falls.", 12, MID, "start"))
    return _save("finding-zones", "threshold-percent.svg", W, H, b, "Four range bars on a scale of percentage of maximum heart rate: two rules for Zone 2, at 60 to 70 and 72 to 82 percent, and the measured first lactate threshold, at 78 to 84 percent in two thirds of 50 trained cyclists and from 60 to 90 percent across 100 adults")


def lactate_steps():
    """Schematic of a step test read two ways: lactate against the rider's baseline, and the talk test. Values are made up."""
    W, H = 680, 447
    left, right, top, base = 86, 620, 104, 300
    vals = [1.1, 1.0, 1.1, 1.2, 1.3, 1.9, 2.8]
    talk = ["yes", "yes", "yes", "yes", "yes", "not sure", "no"]
    n = len(vals)
    sw = (right - left) / n
    Y = lambda v: base - v / 3.2 * (base - top)
    cx = lambda i: left + (i + 0.5) * sw
    bl = sum(vals[:4]) / 4
    b = [text(30, 28, "Zone 2 ends at the last stage before lactate rises", 14, INK, "start", "600"),
         text(30, 47, "A step test of four-minute stages, about 15 W apart, with made-up values: blood lactate", 12, MID, "start"),
         text(30, 63, "at the end of each stage, and the answer to “Could I speak comfortably?”", 12, MID, "start")]
    hit = 4
    b.append(f'<rect x="{left + hit * sw + 3:.1f}" y="{top - 6}" width="{sw - 6:.1f}" height="{base - top + 62}" fill="{BAND}"/>')
    b.append(f'<line x1="{left}" y1="{base}" x2="{right}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    b.append(f'<line x1="{left}" y1="{top}" x2="{left}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (0, 1, 2, 3):
        b.append(f'<line x1="{left - 5}" y1="{Y(v):.1f}" x2="{left}" y2="{Y(v):.1f}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(left - 10, Y(v) + 4, str(v), 12, MID, "end"))
    b.append(text(left - 44, (top + base) / 2, "Blood lactate (mmol/L)", 12, MID, "middle", style=f'transform="rotate(-90 {left - 44} {(top + base) / 2})"'))
    for v, lab in ((bl, "baseline"), (bl + 0.5, "baseline + 0.5")):
        b.append(f'<line x1="{left}" y1="{Y(v):.1f}" x2="{right}" y2="{Y(v):.1f}" stroke="{MID}" stroke-width="1" stroke-dasharray="4 4"/>')
        b.append(text(right - 4, Y(v) + 14, lab, 11.5, MID, "end"))
    pts = " ".join(f"{cx(i):.1f},{Y(v):.1f}" for i, v in enumerate(vals))
    b.append(f'<polyline points="{pts}" fill="none" stroke="{INK}" stroke-width="2"/>')
    for i, v in enumerate(vals):
        b.append(f'<circle cx="{cx(i):.1f}" cy="{Y(v):.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        ly = Y(v) + 21 if i == 4 else (Y(v) - 12 if i < 5 else Y(v) - 6)
        halo = f'paint-order="stroke" stroke="{BAND}" stroke-width="5"' if i == 4 else ""
        b.append(text(cx(i) + (0 if i < 5 else -14), ly, f"{v:.1f}", 12, INK, "middle" if i < 5 else "end", "600", halo))
        b.append(text(cx(i), base + 20, f"stage {i + 1}", 12, MID, "middle"))
        b.append(text(cx(i), base + 46, talk[i], 12.5, INK, "middle", "600" if i >= 4 else "400"))
    b.append(text(left - 10, base + 46, "speak?", 12, MID, "end"))
    b.append(text(cx(hit), top + 10, "top of", 12, INK, "middle"))
    b.append(text(cx(hit), top + 26, "Zone 2", 12.5, INK, "middle", "600"))
    b.append(text(left, base + 84, "The first four readings differ by a tenth or two, as a meter’s will. Their average, 1.1, is the baseline.", 12, MID, "start"))
    b.append(text(left, base + 101, "Stage 6 is the first to read 0.5 mmol/L above it, and stage 7 confirms it by reading higher still.", 12, MID, "start"))
    b.append(text(left, base + 118, "The top of Zone 2 is the power and heart rate of stage 5.", 12, MID, "start"))
    return _save("finding-zones", "lactate-steps.svg", W, H, b, "Sketch of a seven-stage step test: lactate flat for five stages then rising, with talk-test answers of yes, not sure and no")


def mito_efficiency():
    """Two bar panels: change in mitochondrial content per programme and per hour, by kind of training (Mølmen 2025)."""
    rows = _rows("easy-riding", "molmen2025.csv")
    W, H = 680, 380
    base, top = 290, 110
    b = [text(30, 28, "Continuous riding adds as much mitochondrial content as intervals, in more hours", 14, INK, "start", "600"),
         text(30, 47, "Change in the muscle’s mitochondrial content after a training programme, and the same change", 12, MID, "start"),
         text(30, 63, "per hour of training relative to continuous riding. Pooled from 353 studies.", 12, MID, "start")]
    panels = [(70, "After a whole programme", "change", 30.0, lambda v: f"+{v:.0f}%"),
              (390, "Per hour of training", "efficiency", 4.2, lambda v: f"{v:.1f}×")]
    bw, gap = 62, 24
    for x0, head, key, vmax, fmt in panels:
        b.append(text(x0, top - 22, head, 12.5, INK, "start", "600"))
        b.append(f'<line x1="{x0}" y1="{base}" x2="{x0 + 3 * bw + 2 * gap}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
        for i, r in enumerate(rows):
            v = float(r[key])
            h = v / vmax * (base - top)
            x = x0 + i * (bw + gap)
            fill = INK if i == 0 else FAINT
            b.append(f'<rect x="{x}" y="{base - h:.1f}" width="{bw}" height="{h:.1f}" fill="{fill}"/>')
            b.append(text(x + bw / 2, base - h - 8, fmt(v), 13, INK, "middle", "600"))
            words = r["label"].split(" ")
            l1 = " ".join(words[:-1]) if len(words) > 1 else words[0]
            l2 = words[-1] if len(words) > 1 else ""
            b.append(text(x + bw / 2, base + 18, l1, 11.5, INK, "middle"))
            b.append(text(x + bw / 2, base + 33, l2, 11.5, INK, "middle"))
    b.append(text(70, base + 62, "Continuous riding here means everything below the second threshold, easy and moderate together.", 12, MID, "start"))
    return _save("easy-riding", "mito-efficiency.svg", W, H, b, "Bar charts of the change in mitochondrial content after continuous, interval and sprint training, per programme and per hour")


def fatmax_feeding():
    """Dot plot, one row per feeding condition: peak fat burning (circle) and, where measured, the first lactate rise (square)."""
    rows = _rows("easy-riding", "fatmax-feeding.csv")
    W, left, right, top, rh = 680, 250, 600, 132, 46
    lo, hi = 45.0, 75.0
    X = lambda v: left + (v - lo) / (hi - lo) * (right - left)
    base = top + rh * len(rows)
    H = base + 58
    b = [text(30, 28, "After carbohydrate, peak fat burning falls below the first threshold", 14, INK, "start", "600"),
         text(30, 47, "The intensity at which fat burning peaked in four feeding conditions, and the intensity of the", 12, MID, "start"),
         text(30, 63, "first rise in blood lactate in the two studies that measured it. Both as a percentage of VO₂max.", 12, MID, "start")]
    ky = 92
    b.append(f'<circle cx="{left + 6}" cy="{ky}" r="5.5" fill="{INK}"/>')
    b.append(text(left + 18, ky + 4, "Peak fat burning", 12, INK, "start", "600"))
    b.append(f'<rect x="{left + 142}" y="{ky - 5.5}" width="11" height="11" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
    b.append(text(left + 161, ky + 4, "First rise in blood lactate", 12, INK, "start", "600"))
    for v in (45, 50, 55, 60, 65, 70, 75):
        b.append(f'<line x1="{X(v):.1f}" y1="{top - 8}" x2="{X(v):.1f}" y2="{base}" stroke="{BAND}" stroke-width="1"/>')
    b.append(f'<line x1="{X(lo):.1f}" y1="{base}" x2="{X(hi):.1f}" y2="{base}" stroke="{MID}" stroke-width="1"/>')
    for v in (45, 50, 55, 60, 65, 70, 75):
        b.append(f'<line x1="{X(v):.1f}" y1="{base}" x2="{X(v):.1f}" y2="{base + 5}" stroke="{MID}" stroke-width="1"/>')
        b.append(text(X(v), base + 20, f"{v}%", 12, MID, "middle"))
    b.append(text((X(lo) + X(hi)) / 2, base + 40, "Percentage of VO₂max", 12, MID, "middle"))
    halo = 'paint-order="stroke" stroke="#ffffff" stroke-width="4"'
    for i, r in enumerate(rows):
        y = top + rh * i + rh / 2 - 2
        b.append(text(left - 20, y - 2, r["label"], 13, INK, "end", "600"))
        b.append(text(left - 20, y + 13, r["note"], 11.5, MID, "end"))
        f = float(r["fatmax"])
        l = float(r["lactate"]) if r["lactate"] else None
        side = 1 if l is None or f > l else -1
        if l is not None:
            b.append(f'<line x1="{X(min(f, l)):.1f}" y1="{y:.1f}" x2="{X(max(f, l)):.1f}" y2="{y:.1f}" stroke="{FAINT}" stroke-width="1.5"/>')
            b.append(f'<rect x="{X(l) - 5.5:.1f}" y="{y - 5.5:.1f}" width="11" height="11" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
            b.append(text(X(l) - side * 12, y + 4, f"{l:.0f}%", 12, INK, "end" if side > 0 else "start", "400", halo))
        b.append(f'<circle cx="{X(f):.1f}" cy="{y:.1f}" r="5.5" fill="{INK}" stroke="#ffffff" stroke-width="2"/>')
        b.append(text(X(f) + side * 12, y + 4, f"{f:.0f}%", 12, INK, "start" if side > 0 else "end", "600", halo))
    return _save("easy-riding", "fatmax-feeding.svg", W, H, b, "Peak fat burning at 63, 60, 52 and 56 percent of VO2max in four feeding conditions, with the first lactate rise at 61 percent in the first and 69 percent in the last")


FIGURES = {"ventoux": ventoux, "epo-loop": epo_loop, "oxygen-route": oxygen_route, "cp-decline": cp_decline,
           "carb-dose": carb_dose, "hb-timeline": heat_timeline, "detraining": detraining, "atp-cycle": atp_cycle, "sawtooth": sawtooth, "pain-training": pain_training, "small-trials": small_trials, "carb-curve": carb_curve, "strength-effects": strength_effects,
           "zone-maps": zone_maps, "zone2-markers": zone2_markers,
           "threshold-percent": threshold_percent, "lactate-steps": lactate_steps,
           "mito-efficiency": mito_efficiency, "fatmax-feeding": fatmax_feeding}

if __name__ == "__main__":
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, fn in FIGURES.items():
        if want in name:
            print(fn())
