#!/usr/bin/env python3
"""Build report data: human HR-power slope (open-loop, within-ride), per-ride HR
at a reference effort for every ride (incl. JustZone2), temperature effect.
    python zone2_hr_report_data.py output/zone2_study
Writes report_data.json next to the data.
"""
import json, sys
from pathlib import Path
import numpy as np, pandas as pd, statsmodels.formula.api as smf
sys.path.insert(0, str(Path(__file__).parent))
from zone2_hr_beta import load_ride

root = Path(sys.argv[1])
rides = pd.read_csv(root / "rides.csv", dtype={"id": str})
rides["source"] = rides.source.replace({"other": "Zwift"})
rides["date"] = pd.to_datetime(rides.start_local.str[:10])
temps = pd.read_csv(root / "temps_croydon.csv", dtype={"id": str})
rides = rides.merge(temps, on="id")

bins = []
for r in rides.itertuples():
    b = load_ride(root / "streams" / f"{r.id}.csv")
    if b is None: continue
    b["id"], b["source"], b["date"], b["temp_c"] = r.id, r.source, r.date, r.temp_c
    bins.append(b)
B = pd.concat(bins)
B["cad"] = np.where(B.has_cad, B.cadence_rpm, np.nan)

def fe(df):
    d = df.dropna(subset=["cad"])
    m = smf.ols("hr_bpm ~ p_lag + cad + minutes + C(id)", d).fit(
        cov_type="cluster", cov_kwds={"groups": pd.factorize(d.id)[0]})
    ci = m.conf_int()
    return m, {k: dict(est=m.params[k], lo=ci.loc[k, 0], hi=ci.loc[k, 1]) for k in ["p_lag", "cad", "minutes"]}

m_open, coef_open = fe(B[B.source == "Zwift"])
m_jz2, coef_jz2 = fe(B[B.source == "JustZone2"])
beta, gam, dlt = (coef_open[k]["est"] for k in ["p_lag", "cad", "minutes"])
print("open-loop:", {k: round(v["est"], 3) for k, v in coef_open.items()}, "rides", B[B.source=="Zwift"].id.nunique())
print("JZ2      :", {k: round(v["est"], 3) for k, v in coef_jz2.items()})

REF = dict(p=160, cad=85, minutes=30, temp=12)
B["cad_f"] = B.cad.fillna(REF["cad"])
B["adj"] = B.hr_bpm - beta * (B.p_lag - REF["p"]) - gam * (B.cad_f - REF["cad"]) - dlt * (B.minutes - REF["minutes"])
per = B.groupby("id").agg(date=("date", "first"), source=("source", "first"), temp_c=("temp_c", "first"),
                          hr_ref_raw=("adj", "mean"), hr=("hr_bpm", "mean"), watts=("watts", "mean"),
                          has_cad=("has_cad", "first"), mins=("minutes", "size")).reset_index()
per["mins"] = per.mins * 30 / 60
per["q"] = per.date.dt.to_period("Q").astype(str)
mt = smf.ols("hr_ref_raw ~ temp_c + C(q)", per).fit(cov_type="HC1")
theta, th_lo, th_hi = mt.params.temp_c, *mt.conf_int().loc["temp_c"]
print("temp coef (within-quarter):", round(theta, 3), round(th_lo, 3), round(th_hi, 3))
per["hr_ref"] = per.hr_ref_raw - theta * (per.temp_c - REF["temp"])
per = per.sort_values("date")
# 60-day centred rolling median for the trend line
s = per.set_index("date").hr_ref
trend = s.rolling("61D", center=True, min_periods=4).median()
per["trend"] = trend.values
per["w_at_140"] = REF["p"] + (140 - per.hr_ref) / beta

# ---- watts at reference HR (the study's headline measure) ----
HR_REF = 145
per["wy"] = REF["p"] + (HR_REF - per.hr_ref) / beta
per["yrs"] = (per.date - per.date.min()).dt.days / 365.25
s = per.set_index("date").wy
per["wtr"] = s.rolling("61D", center=True, min_periods=4).median().values
def trend(df, col="wy"):
    m = smf.ols(f"{col} ~ yrs", df).fit(cov_type="HC1"); ci = m.conf_int().loc["yrs"]
    return dict(est=round(m.params.yrs, 2), lo=round(ci[0], 2), hi=round(ci[1], 2))
trends = dict(all=trend(per), zwift=trend(per[per.source == "Zwift"]),
              jz2=trend(per[per.source == "JustZone2"]))
sens = []
for b in (coef_jz2["p_lag"]["est"], beta, 0.45):
    hr_at_own_p = per.hr_ref + beta * (per.watts - REF["p"])
    w = per.watts + (HR_REF - hr_at_own_p) / b
    d = per.assign(wb=w)
    t = trend(d, "wb")
    sens.append(dict(beta=round(b, 2), trend=t,
                     yearly={int(k): int(round(v)) for k, v in d.groupby(d.date.dt.year).wb.median().items()}))
print("trends", trends); print("sens", sens)
roll = pd.read_csv(root / "hr_beta_rolling.csv")
yr = per.groupby(per.date.dt.year).agg(rides=("id", "size"), hr_ref=("hr_ref", "median"), wy=("wy", "median"),
                                       watts=("watts", "median"), hr=("hr", "median")).round(1)
print(yr)
out = dict(
    ref=REF, hr_ref=HR_REF, trends=trends, sens=sens,
    coef_open={k: {kk: round(vv, 4) for kk, vv in v.items()} for k, v in coef_open.items()},
    coef_jz2={k: {kk: round(vv, 4) for kk, vv in v.items()} for k, v in coef_jz2.items()},
    temp=dict(est=round(theta, 3), lo=round(th_lo, 3), hi=round(th_hi, 3)),
    n=dict(rides_total=int(len(rides)), rides_used=int(len(per)),
           open_rides=int((per.source == "Zwift").sum()), jz2_rides=int((per.source == "JustZone2").sum()),
           hours=round(float(per.mins.sum() / 60), 1), no_hr=int((rides.has_hr == 0).sum())),
    per_ride=[dict(id=r.id, d=r.date.strftime("%Y-%m-%d"), s=r.source, t=round(r.temp_c, 1),
                   y=round(r.hr_ref, 1), wy=round(r.wy, 1), wtr=None if pd.isna(r.wtr) else round(r.wtr, 1),
                   hr=round(r.hr, 1), w=round(r.watts, 1), m=round(r.mins), cad=bool(r.has_cad))
              for r in per.itertuples()],
    rolling=[dict(d=r.date, b=round(r.beta, 3), lo=round(r.beta_lo, 3), hi=round(r.beta_hi, 3),
                  n=int(r.rides), jz=("JustZone2" in r.sources)) for r in roll.itertuples()],
    yearly=yr.reset_index().rename(columns={"date": "year"}).to_dict("records"),
)
(root / "report_data.json").write_text(json.dumps(out))
print("wrote", root / "report_data.json", len(out["per_ride"]), "rides")
