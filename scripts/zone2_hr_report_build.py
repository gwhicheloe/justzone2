#!/usr/bin/env python3
"""Fill report_template.html with report_data.json -> hr_beta_report.html"""
import json, statistics as st, sys
from pathlib import Path

root = Path(sys.argv[1])
j = json.loads((root / "report_data.json").read_text())
s = (root / "report_template.html").read_text()
co, t, n, rides = j["coef_open"], j["temp"], j["n"], j["per_ride"]


def phase(a, b):
    w = sorted(r["wy"] for r in rides if a <= r["d"] <= b)
    q = st.quantiles(w, n=4)
    return round(st.median(w)), len(w), f"{round(q[0])}–{round(q[2])}"


P1, P2, P3 = phase("2023-01-01", "2024-12-31"), phase("2025-09-01", "2026-01-31"), phase("2026-09-15", "2026-12-31")
peak = max((r for r in rides if r["wtr"] is not None and r["d"] < "2025-01-01"), key=lambda r: r["wtr"])
years = [y["year"] for y in j["yearly"]]
vals = {
    "RIDES_USED": n["rides_used"], "RIDES_TOTAL": n["rides_total"], "HOURS": round(n["hours"]), "NO_HR": n["no_hr"],
    "P1": P1[0], "P1N": P1[1], "P1Q": P1[2], "P2": P2[0], "P2N": P2[1], "P2Q": P2[2],
    "P3": P3[0], "P3N": P3[1], "P3Q": P3[2], "DROP": P1[0] - P2[0], "PEAK": round(peak["wtr"]),
    "TR": f'{j["trends"]["all"]["est"]:+.1f}',
    "BETA": f'{co["p_lag"]["est"]:.2f}', "BETA_LO": f'{co["p_lag"]["lo"]:.2f}', "BETA_HI": f'{co["p_lag"]["hi"]:.2f}',
    "DRIFT": f'{co["minutes"]["est"] * 60:.0f}', "CAD": f'{co["cad"]["est"]:.2f}',
    "TEMP": f'{t["est"]:+.2f}', "TEMP_LO": f'{t["lo"]:+.2f}', "TEMP_HI": f'{t["hi"]:+.2f}',
    "YEAR_ROWS": "".join(f'<tr><td class="n">{y["year"]}</td><td class="n">{y["rides"]}</td><td class="n">{round(y["wy"])}</td>'
                         f'<td class="n">{round(y["watts"])}</td><td class="n">{round(y["hr"])}</td></tr>' for y in j["yearly"]),
    "SENS_HEAD": "".join(f"<th>{y}</th>" for y in years),
    "SENS_ROWS": "".join(f'<tr><td class="n">{x["beta"]:.2f} bpm/W</td>' +
                         "".join(f'<td class="n">{x["yearly"][str(y)]}</td>' for y in years) + "</tr>" for x in j["sens"]),
    "DATA": json.dumps({"per_ride": rides}, separators=(",", ":")),
}
for k, v in vals.items():
    s = s.replace(f"__{k}__", str(v))
left = [l for l in s.split("\n") if "__" in l]
assert not left, left[:3]
(root / "hr_beta_report.html").write_text(s)
print(root / "hr_beta_report.html", len(s), "bytes;", "phases", P1, P2, P3, "peak", round(peak["wtr"]), peak["d"])
