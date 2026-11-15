# Zone 2 power study (Nov 2026)

How many watts George holds at a given heart rate, Nov 2022 – Nov 2026, from
322 Strava Zone 2 rides at 1-second resolution. This study is the origin of the
in-app **Zone 2 power** feature (`Models/HRNormalisation.swift`,
`Services/NormalisedHistoryService.swift`).

## Scripts

| Script | What it does |
|---|---|
| `scripts/strava_zone2_export.py` | `auth` / `export`. OAuth via the Cloudflare worker; token in `~/.private_keys/strava_study_token.json`. Self-throttles (≤50 reads/15 min, pauses at half the app-wide limit, stops at 800/day) because the Strava quota is shared with every JustZone2 user. Resumable. Writes `output/zone2_study/streams/{id}.csv`, `rides.csv`, `activity_meta.json`. |
| `scripts/zone2_hr_beta.py` | `load_ride` / `steady_segment` (shared), plus the rolling pooled HR-on-power model. |
| `scripts/zone2_hr_report_data.py` | Fixed-effects fits, per-ride watts at 145 bpm, rolling median, sensitivity → `report_data.json`. |
| `scripts/zone2_hr_report_build.py` | Fills `output/zone2_study/report_template.html` → `hr_beta_report.html`. |
| `scripts/zone2_hr_beta_plot.py` | Early matplotlib chart (superseded by the HTML report). |

`output/zone2_study/` (raw rides, the report and its template) is **deliberately
not in git**: it is personal ride data and the repo is public. Python deps
(numpy, pandas, statsmodels) are not installed system-wide; use a venv.

Private report: https://claude.ai/artifact/UoPBmScWtj8hMpj3ZMnSNX

## Method

- 30-s bins of the steady section (warm-up cut until 5 min after 60-s power
  reaches 90% of the ride median, never before minute 10; cool-down cut after
  the last such point). Bins with <50 W, HR outside 60–200, or <50 rpm are dropped.
- Power lagged with a 45-s EMA.
- Within-ride fixed effects: `HR ~ β·P_lag + γ·cadence + δ·minutes + ride`,
  SEs clustered by ride. Fit on Zwift (open-loop) rides: β 0.32 bpm/W
  [0.29, 0.35], γ 0.12 bpm/rpm, δ ≈ 5 bpm/h.
- Per ride: adjust every bin to 160 W, 85 rpm, minute 30, average → HR at the
  reference; watts at 145 bpm = 160 + (145 − HR) / β. Trend = 61-day centred
  rolling median.
- **Zone Targeting is closed loop** (HR sets power), which biases β low on
  JustZone2 rides (0.21 vs 0.32). Measuring power at the rider's own target HR
  keeps the β conversion small, which is what the app does.
- Temperature (Croydon hourly, Open-Meteo) had no measurable effect
  (+0.07 bpm/°C, CI −0.11 to +0.26) and was dropped. Open-Meteo's free tier is
  non-commercial: don't use it for anything in the book without a licence check.

## Findings: watts at 145 bpm

| Period | Median | IQR | Rides |
|---|---|---|---|
| 2023–24 | 174 W | 159–185 | 102 |
| Sep 2025 – Jan 2026 | 148 W | 139–160 | 35 |
| Mid-Sep – Nov 2026 | 177 W | 174–184 | 13 |

Rolling peak before 2025: 187 W (21 Dec 2023). Dip in autumn 2023 to ~138 W.
The overall linear trend (−3.6 W/yr) is misleading: the shape is a U. The shape
is the same with β = 0.21, 0.32 or 0.45.

## Drift through time (prototype, not yet in the app)

Per ride, with β 0.32 and γ 0.12 fixed: drift = slope of (HR − β·P − γ·cad)
over the steady section, in bpm/h.

| | 2022 | 2023 | 2024 | 2025 | 2026 JZ2 | 2026 Zwift |
|---|---|---|---|---|---|---|
| Drift, bpm/h (median) | 2.9 | 2.9 | 5.2 | 7.8 | 6.6 | 5.9 |
| Friel decoupling, % | 1.4–1.7 (2022–24) | | | 2.4 | 4.3 | 1.4 |

- Drift in bpm/h is consistent across sources; Friel's decoupling % is not
  (4.3% on JustZone2 vs 1.4% on Zwift in the same year), so show bpm/h.
- Per-ride noise is large (SD 5.7 bpm/h), so it needs a rolling median like
  Zone 2 power. Drift and decoupling correlate at 0.73.
- The prototype script lived in a scratchpad and is gone; rebuild it from the
  definition above (the engine's per-ride bins already have everything needed).

## Open questions before showing more in the app

1. **Drift through time**: the engine fits one pooled δ; a per-ride drift
   (residual slope) plus a rolling median would give the chart above.
2. **Cadence cost**: γ is 0.12 bpm/rpm on Zwift rides but 0.61 on JustZone2
   rides. Explain that gap before showing users a cadence number.
