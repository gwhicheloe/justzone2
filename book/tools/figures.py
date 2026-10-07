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


FIGURES = {"ventoux": ventoux, "epo-loop": epo_loop, "oxygen-route": oxygen_route, "cp-decline": cp_decline,
           "carb-dose": carb_dose, "hb-timeline": heat_timeline}

if __name__ == "__main__":
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    for name, fn in FIGURES.items():
        if want in name:
            print(fn())
