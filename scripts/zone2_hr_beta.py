#!/usr/bin/env python3
"""Rolling pooled 'heart-rate beta' model over the exported Zone 2 rides.

Needs: numpy pandas statsmodels matplotlib
    python zone2_hr_beta.py output/zone2_study [--temps temps.csv]

For each date on a weekly grid, pools the 30-s bins of every ride in a
centred window and fits (OLS, SEs clustered by ride):

    HR = a + beta*P_lag + g*cadence + d*minutes_into_ride [+ t*ambient_temp]

P_lag is power smoothed with a 45-s EMA (HR lags power). Warm-up and
cool-down are cut per ride (see steady_segment). Outputs beta(t) and HR at
a reference effort, with 95% CIs, to hr_beta_rolling.csv + hr_beta.png.
"""
import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

BIN_S = 30
EMA_TAU_S = 45
WINDOW_DAYS = 28          # +/- 28 days = 8-week centred window
MIN_RIDES = 6
REF = dict(p_lag=160.0, cadence=85.0, minutes=30.0, temp_c=12.0)


def steady_segment(d):
    """Cut warm-up and cool-down.

    Warm-up ends 5 min after 60-s smoothed power first reaches 90% of the
    ride's median power, and never before minute 10. Cool-down starts after
    the last time smoothed power is still >= 90% of median.
    """
    p60 = d.watts.rolling(60, min_periods=30).mean()
    med = d.watts[d.watts > 50].median()
    hit = p60[p60 >= 0.9 * med]
    if hit.empty:
        return d.iloc[0:0]
    start = max(600, hit.index[0] + 300)
    end = hit.index[-1]
    return d.loc[start:end]


def load_ride(path):
    d = pd.read_csv(path)
    if d.hr_bpm.isna().all() or d.watts.isna().all():
        return None
    d = d.drop_duplicates("t_s").set_index("t_s")
    d = d.reindex(range(int(d.index.max()) + 1)).ffill(limit=5)
    d["p_lag"] = d.watts.ewm(alpha=1 / EMA_TAU_S).mean()
    d["minutes"] = d.index / 60
    d = steady_segment(d)
    has_cad = d.cadence_rpm.fillna(0).gt(0).mean() > 0.8
    keep = (d.watts >= 50) & d.hr_bpm.between(60, 200)
    if has_cad:
        keep &= d.cadence_rpm >= 50
    d = d[keep].dropna(subset=["hr_bpm", "p_lag"])
    if len(d) < 15 * 60:          # need >= 15 min of steady riding
        return None
    b = d.groupby(d.index // BIN_S)[["hr_bpm", "watts", "p_lag", "cadence_rpm", "minutes"]].mean()
    b["has_cad"] = has_cad
    return b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("study_dir")
    ap.add_argument("--temps", help="CSV with id,temp_c (ambient at ride start)")
    ap.add_argument("--sources", default="JustZone2,Zwift")
    args = ap.parse_args()
    root = Path(args.study_dir)

    rides = pd.read_csv(root / "rides.csv", dtype={"id": str})
    rides["date"] = pd.to_datetime(rides.start_local.str[:10])
    rides = rides[rides.source.isin(args.sources.split(","))]
    if args.temps:
        rides = rides.merge(pd.read_csv(args.temps, dtype={"id": str}), on="id", how="left")

    bins, per_ride = [], []
    for r in rides.itertuples():
        b = load_ride(root / "streams" / f"{r.id}.csv")
        if b is None:
            continue
        b["id"], b["date"], b["source"] = r.id, r.date, r.source
        if args.temps:
            b["temp_c"] = r.temp_c
        bins.append(b)
        per_ride.append(dict(id=r.id, date=r.date, source=r.source, bins=len(b),
                             hr=b.hr_bpm.mean(), watts=b.watts.mean(), p_sd=b.p_lag.std(),
                             cad=b.cadence_rpm.mean() if b.has_cad.iloc[0] else np.nan))
    allb = pd.concat(bins)
    pr = pd.DataFrame(per_ride)
    pr.to_csv(root / "hr_beta_rides_used.csv", index=False)
    print(f"{len(pr)} rides usable ({pr.source.value_counts().to_dict()}), {len(allb)} bins")

    use_temp = bool(args.temps) and allb.temp_c.notna().any()
    out = []
    grid = pd.date_range(pr.date.min(), pr.date.max(), freq="7D")
    for t in grid:
        w = allb[(allb.date >= t - pd.Timedelta(days=WINDOW_DAYS)) &
                 (allb.date <= t + pd.Timedelta(days=WINDOW_DAYS))]
        n_rides = w.id.nunique()
        if n_rides < MIN_RIDES:
            continue
        cad_ok = w.has_cad.all()
        terms = ["p_lag", "minutes"] + (["cadence_rpm"] if cad_ok else [])
        if use_temp:
            w = w.dropna(subset=["temp_c"])
            if w.temp_c.std() > 0.5:
                terms.append("temp_c")
        f = "hr_bpm ~ " + " + ".join(terms)
        m = smf.ols(f, data=w).fit(cov_type="cluster", cov_kwds={"groups": pd.factorize(w.id)[0]})
        ref = pd.DataFrame([{**REF, "cadence_rpm": REF["cadence"]}])
        pred = m.get_prediction(ref).summary_frame(alpha=0.05).iloc[0]
        ci = m.conf_int()
        out.append(dict(
            date=t.date(), rides=n_rides, bins=len(w),
            sources="/".join(sorted(w.source.unique())),
            beta=m.params.p_lag, beta_lo=ci.loc["p_lag", 0], beta_hi=ci.loc["p_lag", 1],
            hr_ref=pred["mean"], hr_ref_lo=pred["mean_ci_lower"], hr_ref_hi=pred["mean_ci_upper"],
            drift_bpm_per_min=m.params.minutes,
            cad_coef=m.params.get("cadence_rpm", np.nan),
            temp_coef=m.params.get("temp_c", np.nan),
            power_range_w=w.p_lag.quantile(.95) - w.p_lag.quantile(.05),
            r2=m.rsquared,
        ))
    res = pd.DataFrame(out)
    res.to_csv(root / "hr_beta_rolling.csv", index=False)
    pd.set_option("display.width", 220)
    print(res.round(3).to_string(index=False))


if __name__ == "__main__":
    main()
