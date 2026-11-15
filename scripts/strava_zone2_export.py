#!/usr/bin/env python3
"""Export per-second HR / power / cadence for every Zone 2 ride on Strava.

    python3 scripts/strava_zone2_export.py auth     # one-time browser authorise
    python3 scripts/strava_zone2_export.py export   # resumable; re-run any time

Auth goes through the JustZone2 Cloudflare worker, so the Strava client secret
never touches this machine. The token lives in ~/.private_keys (outside git).
Output: output/zone2_study/rides.csv (index) + output/zone2_study/streams/{id}.csv
"""
import csv
import http.server
import json
import re
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

CLIENT_ID = "197806"  # public; also in Constants.swift
WORKER = "https://justzone2-strava-auth.george-whicheloe.workers.dev"
PORT = 8765
REDIRECT = f"http://localhost:{PORT}/callback"
TOKEN_FILE = Path.home() / ".private_keys" / "strava_study_token.json"
OUT = Path(__file__).resolve().parent.parent / "output" / "zone2_study"
STREAMS = OUT / "streams"
API = "https://www.strava.com/api/v3"
UA = "justzone2-study-export/1.0"
# This script shares the JustZone2 app's Strava rate limits with every app user.
# Cap our own use well below the limits so the app always has headroom.
MY_CAP_15MIN = 50      # app read limit is 200 / 15 min
MY_CAP_DAY_TOTAL = 800  # stop if app-wide daily reads reach this (limit 2000)


# ---------------------------------------------------------------- auth
def http_json(url, data=None, headers=None):
    body = json.dumps(data).encode() if data is not None else None
    h = {"User-Agent": UA, **(headers or {})}
    if body is not None:
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=h)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r), r.headers


def save_token(tok):
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(json.dumps(tok))
    TOKEN_FILE.chmod(0o600)


def auth():
    url = "https://www.strava.com/oauth/authorize?" + urllib.parse.urlencode({
        "client_id": CLIENT_ID, "response_type": "code", "redirect_uri": REDIRECT,
        "approval_prompt": "auto", "scope": "activity:read_all",
    })
    result = {}

    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "code" not in q and "error" not in q:
                self.send_response(404); self.end_headers(); return
            result.update({k: v[0] for k, v in q.items()})
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "Authorised - you can close this tab." if "code" in q else f"Error: {q['error'][0]}"
            self.wfile.write(f"<h2 style='font-family:sans-serif'>{msg}</h2>".encode())

        def log_message(self, *a):
            pass

    srv = http.server.HTTPServer(("127.0.0.1", PORT), H)
    print("AUTH_URL", url, flush=True)
    while not result:
        srv.handle_request()
    if "code" not in result:
        sys.exit(f"Authorisation failed: {result}")
    if "activity:read_all" not in result.get("scope", ""):
        print("WARNING: activity:read_all not granted; private rides will be missing", flush=True)
    tok, _ = http_json(f"{WORKER}/token", {"code": result["code"]})
    if "access_token" not in tok:
        sys.exit(f"Token exchange failed: {tok}")
    save_token(tok)
    print("AUTH_OK token saved to", TOKEN_FILE, flush=True)


def access_token():
    if not TOKEN_FILE.exists():
        sys.exit("No token - run: python3 scripts/strava_zone2_export.py auth")
    tok = json.loads(TOKEN_FILE.read_text())
    if tok["expires_at"] - time.time() < 300:
        new, _ = http_json(f"{WORKER}/refresh", {"refresh_token": tok["refresh_token"]})
        if "access_token" not in new:
            sys.exit(f"Refresh failed: {new}")
        tok = new
        save_token(tok)
    return tok["access_token"]


# ---------------------------------------------------------------- API with rate limiting
def api(path, params=None):
    url = f"{API}{path}" + ("?" + urllib.parse.urlencode(params) if params else "")
    while True:
        try:
            data, headers = http_json(url, headers={"Authorization": f"Bearer {access_token()}"})
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait_for_window("429 rate limited")
                continue
            if e.code == 404:
                return None
            raise
        throttle(headers)
        return data


def wait_for_window(reason):
    now = time.time()
    wait = 900 - (now % 900) + 15  # Strava windows reset on the quarter hour
    print(f"  {reason}; sleeping {int(wait)}s until next 15-min window", flush=True)
    time.sleep(wait)


def throttle(headers):
    # Strava reports "15min,daily" usage/limits; prefer the read-specific pair.
    for u_key, l_key in (("X-ReadRateLimit-Usage", "X-ReadRateLimit-Limit"),
                         ("X-RateLimit-Usage", "X-RateLimit-Limit")):
        u, l = headers.get(u_key), headers.get(l_key)
        if u and l:
            used15, used_day = map(int, u.split(","))
            lim15, lim_day = map(int, l.split(","))
            if used_day >= min(MY_CAP_DAY_TOTAL, lim_day - 2):
                sys.exit(f"Daily cap reached ({used_day}/{lim_day} app-wide). Re-run tomorrow; it resumes.")
            # usage is app-wide; we allow ourselves MY_CAP_15MIN of it
            throttle.mine = getattr(throttle, "mine", 0) + 1
            window = int(time.time() // 900)
            if getattr(throttle, "window", None) != window:
                throttle.window, throttle.mine = window, 1
            if throttle.mine >= MY_CAP_15MIN or used15 >= lim15 // 2:
                wait_for_window(f"self-cap: ours {throttle.mine}, app-wide {used15}/{lim15}")
                throttle.mine = 0
            return


# ---------------------------------------------------------------- selection + parsing
RIDE_TYPES = {"Ride", "VirtualRide", "EBikeRide", "GravelRide", "MountainBikeRide"}


def is_zone2(a):
    """Same rule as HistoryViewModel.isZone2Activity, restricted to rides."""
    name = a.get("name", "")
    if name.startswith("Intervals:"):
        return False
    if a.get("sport_type", a.get("type")) not in RIDE_TYPES:
        return False
    n = name.lower()
    return "zone 2" in n or "zone2" in n or "z2" in n


def source_of(a, desc):
    if "Recorded with JustZone2" in (desc or "") or a["name"] == "Zone 2 Workout":
        return "JustZone2"
    if a["name"].startswith("Zwift"):
        return "Zwift"
    return "other"


def parse_desc(desc):
    d = desc or ""
    g = lambda pat: (m.group(1) if (m := re.search(pat, d)) else "")
    zt = re.search(r"Zone targeting:\s*(On|Off)(?:\s*\(HR\s*(\d+)\D+(\d+)\s*bpm\))?", d)
    return {
        "target_power_w": g(r"Target power:\s*(\d+)"),
        "planned_min": g(r"Duration:\s*(\d+)\s*min"),
        "zone_targeting": zt.group(1) if zt else "",
        "zt_hr_low": zt.group(2) if zt and zt.group(2) else "",
        "zt_hr_high": zt.group(3) if zt and zt.group(3) else "",
        "warm_up": g(r"Warm-up:\s*(On|Off)"),
        "hr_source": g(r"HR source:\s*([^\n]+)").strip(),
    }


def mean_nz(xs):
    v = [x for x in xs if x]
    return round(statistics.fmean(v), 1) if v else ""


# ---------------------------------------------------------------- export
INDEX_COLS = [
    "id", "start_local", "name", "sport_type", "source", "elapsed_s", "moving_s",
    "samples", "has_hr", "has_watts", "has_cadence",
    "avg_hr", "max_hr", "avg_watts_nz", "avg_cadence_nz",
    "target_power_w", "planned_min", "zone_targeting", "zt_hr_low", "zt_hr_high",
    "warm_up", "hr_source", "strava_calories", "flags", "description",
]


def export():
    STREAMS.mkdir(parents=True, exist_ok=True)
    print("Listing activities...", flush=True)
    acts, page = [], 1
    while True:
        batch = api("/athlete/activities", {"per_page": 200, "page": page})
        if not batch:
            break
        acts += batch
        print(f"  page {page}: {len(batch)} (total {len(acts)})", flush=True)
        page += 1
    rides = sorted((a for a in acts if is_zone2(a)), key=lambda a: a["start_date_local"])
    print(f"{len(acts)} activities, {len(rides)} Zone 2 rides", flush=True)

    meta_cache = OUT / "activity_meta.json"
    meta = json.loads(meta_cache.read_text()) if meta_cache.exists() else {}

    rows = []
    for i, a in enumerate(rides, 1):
        aid = str(a["id"])
        f = STREAMS / f"{aid}.csv"
        # The list endpoint has no description; fetch detail once and cache it.
        if aid not in meta and source_of(a, "") == "JustZone2":
            d = api(f"/activities/{aid}") or {}
            meta[aid] = {"description": d.get("description") or "", "calories": d.get("calories")}
            meta_cache.write_text(json.dumps(meta))
        if not f.exists():
            s = api(f"/activities/{aid}/streams",
                    {"keys": "time,heartrate,watts,cadence", "key_by_type": "true"}) or {}
            t = s.get("time", {}).get("data", [])
            cols = {k: s.get(k, {}).get("data") for k in ("heartrate", "watts", "cadence")}
            tmp = f.with_suffix(".tmp")
            with tmp.open("w", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(["t_s", "hr_bpm", "watts", "cadence_rpm"])
                for j, ts in enumerate(t):
                    w.writerow([ts] + [(c[j] if c and j < len(c) else "") for c in cols.values()])
            tmp.rename(f)
            print(f"  [{i}/{len(rides)}] {a['start_date_local'][:10]} {a['name'][:40]}: {len(t)} samples", flush=True)

        # Build index row from the CSV on disk (works for resumed runs too).
        with f.open() as fh:
            data = list(csv.DictReader(fh))
        num = lambda k: [float(r[k]) for r in data if r[k] not in ("", None)]
        hr, wt, cad = num("hr_bpm"), num("watts"), num("cadence_rpm")
        desc = meta.get(aid, {}).get("description", "")
        cal = meta.get(aid, {}).get("calories")
        flags = []
        if not data:
            flags.append("no_streams")
        if cal and a.get("elapsed_time") and cal > 5 * a["elapsed_time"]:
            flags.append("calorie_anomaly")
        if a.get("distance", 0) == 0:
            flags.append("zero_distance")
        if hr and len(hr) < 0.9 * len(data):
            flags.append("hr_gaps")
        rows.append({
            "id": aid, "start_local": a["start_date_local"], "name": a["name"],
            "sport_type": a.get("sport_type", a.get("type")), "source": source_of(a, desc),
            "elapsed_s": a.get("elapsed_time"), "moving_s": a.get("moving_time"),
            "samples": len(data), "has_hr": int(bool(hr)), "has_watts": int(bool(wt)),
            "has_cadence": int(any(cad)),
            "avg_hr": mean_nz(hr), "max_hr": int(max(hr)) if hr else "",
            "avg_watts_nz": mean_nz(wt), "avg_cadence_nz": mean_nz(cad),
            **parse_desc(desc), "strava_calories": cal if cal is not None else "",
            "flags": ";".join(flags), "description": desc.replace("\n", " | "),
        })

    with (OUT / "rides.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=INDEX_COLS)
        w.writeheader()
        w.writerows(rows)
    print(f"EXPORT_DONE {len(rows)} rides -> {OUT/'rides.csv'}", flush=True)


if __name__ == "__main__":
    {"auth": auth, "export": export}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: sys.exit(__doc__))()
