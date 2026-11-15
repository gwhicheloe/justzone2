#!/usr/bin/env python3
"""Plot hr_beta_rolling.csv: beta(t) and HR at reference effort, by era."""
import sys
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

root = Path(sys.argv[1])
r = pd.read_csv(root / "hr_beta_rolling.csv", parse_dates=["date"])
r["era"] = r.sources.str.contains("JustZone2").map({True: "JustZone2 (Zone Targeting on)", False: "Zwift (open loop)"})
COL = {"Zwift (open loop)": "#2a78d6", "JustZone2 (Zone Targeting on)": "#eb6834"}
INK, MUTED, GRID = "#0b0b0b", "#6b6a64", "#e4e3de"

plt.rcParams.update({"font.family": "Helvetica", "font.size": 10, "axes.edgecolor": GRID,
                     "axes.labelcolor": MUTED, "xtick.color": MUTED, "ytick.color": MUTED})
fig, axes = plt.subplots(2, 1, figsize=(11, 7.5), sharex=True, facecolor="#fcfcfb")
panels = [("beta", "beta_lo", "beta_hi", "bpm per W"),
          ("hr_ref", "hr_ref_lo", "hr_ref_hi", "bpm at 160 W, 85 rpm, min 30, 12 °C")]
for ax, (y, lo, hi, lab) in zip(axes, panels):
    ax.set_facecolor("#fcfcfb")
    ax.grid(axis="y", color=GRID, lw=0.8); ax.set_axisbelow(True)
    for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
    for era, g in r.groupby("era"):
        seg = (g.date.diff().dt.days > 14).cumsum()   # break line across gaps
        for _, gg in g.groupby(seg):
            ax.fill_between(gg.date, gg[lo], gg[hi], color=COL[era], alpha=0.15, lw=0)
            ax.plot(gg.date, gg[y], color=COL[era], lw=2, solid_capstyle="round")
    ax.set_ylabel(lab)
axes[0].axhline(0, color=MUTED, lw=0.8)
axes[0].set_title("Open-loop rides put the heart's beta at ~0.3–0.6 bpm/W; with Zone Targeting on it reads ~0, "
                  "because the controller, not the heart, sets power", loc="left", color=INK, fontsize=10.5, wrap=True)
axes[1].set_title("HR at a fixed effort: no steady trend across the Zwift years; in the JustZone2 era it sits near the controller's HR setpoint",
                  loc="left", color=INK, fontsize=10.5)
for era, c in COL.items():
    axes[0].plot([], [], color=c, lw=2, label=era)
axes[0].legend(loc="upper right", frameon=False, fontsize=9)
axes[0].annotate("Zwift (open loop)", (pd.Timestamp("2024-08-01"), 1.0), color=INK, fontsize=9, ha="center")
axes[0].annotate("JustZone2\n(Zone Targeting on)", (pd.Timestamp("2026-06-01"), 0.45), color=INK, fontsize=9, ha="center")
axes[1].xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 7]))
axes[1].xaxis.set_major_formatter(mdates.DateFormatter("%b\n%Y"))
fig.text(0.01, 0.005, "Rolling pooled OLS, 8-week centred window, 30-s bins, warm-up & cool-down removed; "
         "HR ~ lagged power + cadence + minutes + Croydon air temp. Shading = 95% CI (clustered by ride).",
         color=MUTED, fontsize=8)
fig.tight_layout(rect=(0, 0.02, 1, 1))
fig.savefig(root / "hr_beta.png", dpi=150)
print(root / "hr_beta.png")
