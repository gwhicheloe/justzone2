#!/usr/bin/env python3
"""Simulate many small training trials of the same true effect.

Used by the How to read a training study chapter. Two groups of n people; the
training group's true average gain is `TRUE` points larger than the control
group's; individual results scatter with a standard deviation of `SD` points.
Each trial is analysed with an ordinary two-sample t-test at p < 0.05.

  python3 book/tools/simulate_small_trials.py

Prints the summary numbers quoted in the chapter and writes the histogram the
figure is drawn from. The seed is fixed, so the numbers are reproducible.
"""
import math
import os
import random
import statistics as st

TRUE, SD, RUNS, SEED = 3.0, 5.0, 20000, 20261010
TCRIT = {10: 2.101, 50: 1.984}      # two-sided 5% critical values of t for 18 and 98 degrees of freedom
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "chapters", "reading-research", "figures", "small-trials.csv")


def run(n, rng):
    res = []
    for _ in range(RUNS):
        a = [rng.gauss(TRUE, SD) for _ in range(n)]
        b = [rng.gauss(0.0, SD) for _ in range(n)]
        d = st.mean(a) - st.mean(b)
        se = math.sqrt(st.variance(a) / n + st.variance(b) / n)
        res.append((d, abs(d / se) > TCRIT[n]))
    return res


if __name__ == "__main__":
    rng = random.Random(SEED)
    rows = ["# Simulated trials: true advantage 3 points, individual SD 5 points, 20,000 trials per group size, seed 20261010.",
            "# share = fraction of trials whose observed difference fell in the bin [lo, lo+0.5); sig_share = the part of that with p < 0.05.",
            "n,lo,share,sig_share"]
    for n in (10, 50):
        res = run(n, rng)
        ds = sorted(d for d, _ in res)
        sig = [d for d, s in res if s]
        print(f"n={n} per group: significant in {len(sig) / RUNS:.1%} of trials; "
              f"mean difference among significant trials {st.mean(sig):.1f}; "
              f"wrong direction in {sum(1 for d in ds if d < 0) / RUNS:.1%}; "
              f"middle 90% of results {ds[int(RUNS * 0.05)]:.1f} to {ds[int(RUNS * 0.95)]:.1f}")
        for k in range(-12, 26):
            lo = k / 2
            inbin = [(d, s) for d, s in res if lo <= d < lo + 0.5]
            rows.append(f"{n},{lo:.1f},{len(inbin) / RUNS:.4f},{sum(1 for _, s in inbin if s) / RUNS:.4f}")
    open(OUT, "w", encoding="utf-8").write("\n".join(rows) + "\n")
    print(OUT)
