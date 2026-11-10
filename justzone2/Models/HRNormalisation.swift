import Foundation

/// Normalised Zone 2 history: how much power each ride held at the rider's
/// Zone 2 target heart rate, so rides are comparable whatever their heart
/// rate, cadence or length. A port of the study in `scripts/zone2_hr_beta.py`
/// and `scripts/zone2_hr_report_data.py` (Nov 2026), without the temperature
/// term (its effect wasn't measurable).
///
/// Per ride (1 Hz heart rate, power, cadence):
/// 1. Power is smoothed with a 45-s exponential average (heart rate lags power).
/// 2. Only the steady part is kept: from 5 min after 60-s smoothed power first
///    reaches 90% of the ride's median (never before minute 10) to the last
///    time it's still at 90%. Seconds under 50 W, heart rate outside 60–200 or
///    cadence under 50 are dropped. At least 15 steady minutes are needed.
/// 3. The steady part is averaged into 30-second bins.
///
/// Across the rider's Zone 2 rides, one fit with a baseline per ride:
///     HR = ride baseline + β·lagged power + γ·cadence + δ·minutes into the ride
/// with standard errors clustered by ride. β is the rider's heart-rate rise
/// per watt, γ per rpm, δ the drift per minute.
///
/// Each ride is then adjusted to a reference effort (85 rpm, minute 30) and
/// converted along β to the watts it would have held at the target heart rate.
enum HRNormalisation {
    static let binSeconds = 30
    static let emaTau = 45.0
    static let referenceCadence = 85.0
    static let referenceMinute = 30.0
    /// Arbitrary: it cancels out of the watts-at-target result.
    static let referencePower = 160.0
    /// Longer rides are ignored (and it bounds memory: one slot per second).
    static let maxRideSeconds = 8 * 3600
    /// A fitted slope outside this range is treated as no result.
    static let plausibleBeta: ClosedRange<Double> = 0.05...1.5

    /// One ride's second-by-second data (index = seconds from the start;
    /// nil where there's no reading).
    struct Ride {
        let id: String
        let date: Date
        let hr: [Double?]
        let watts: [Double?]
        let cadence: [Double?]
    }

    struct Bin {
        let hr: Double
        let watts: Double
        let pLag: Double
        let cadence: Double?
        let minutes: Double
    }

    struct PreparedRide {
        let id: String
        let date: Date
        let bins: [Bin]
        let hasCadence: Bool
    }

    struct Fit {
        let beta: Double, betaLow: Double, betaHigh: Double
        let cadence: Double, drift: Double
        let rides: Int, bins: Int
        var betaHalfWidth: Double { (betaHigh - betaLow) / 2 }
    }

    struct RidePoint {
        let id: String
        let date: Date
        let watts: Double        // watts at the target heart rate
        var trend: Double?       // 61-day centred rolling median
        /// Estimated from the ride's averages (its full data isn't on the phone yet).
        var isEstimate = false
    }

    /// A ride known only by its averages (Strava's activity summary).
    struct RideSummary {
        let id: String
        let date: Date
        let averageWatts: Double
        let averageHR: Double
        let durationSeconds: Double
    }

    // MARK: - Safe way in

    /// Builds a `Ride` from streams as Strava (or the app) provides them:
    /// parallel arrays of seconds-from-start and readings. Defensive about
    /// anything odd: mismatched lengths (uses the shortest), negative,
    /// duplicate or out-of-order times (ignored), rides longer than
    /// `maxRideSeconds` (rejected) and non-finite readings (dropped).
    static func ride(id: String, date: Date, time: [Int], hr: [Double?], watts: [Double?], cadence: [Double?]?) -> Ride? {
        let count = min(time.count, hr.count, watts.count, cadence?.count ?? Int.max)
        guard count > 0 else { return nil }
        var maxT = -1
        for i in 0..<count where time[i] >= 0 && time[i] <= maxRideSeconds { maxT = max(maxT, time[i]) }
        guard maxT >= 0, time.prefix(count).allSatisfy({ $0 <= maxRideSeconds }) else { return nil }
        var h = [Double?](repeating: nil, count: maxT + 1), w = h, c = h
        func clean(_ v: Double?) -> Double? { guard let v, v.isFinite else { return nil }; return v }
        for i in 0..<count {
            let t = time[i]
            guard t >= 0, t <= maxT, h[t] == nil, w[t] == nil else { continue }   // first reading per second wins
            h[t] = clean(hr[i]); w[t] = clean(watts[i]); c[t] = clean(cadence?[i] ?? nil)
        }
        return Ride(id: id, date: date, hr: h, watts: w, cadence: c)
    }

    // MARK: - Per ride

    static func prepare(_ ride: Ride) -> PreparedRide? {
        let n = ride.hr.count
        guard n > 0, n <= maxRideSeconds + 1, ride.watts.count == n, ride.cadence.count == n,
              ride.hr.contains(where: { $0 != nil }), ride.watts.contains(where: { $0 != nil }) else { return nil }
        let hr = forwardFill(ride.hr, limit: 5)
        let watts = forwardFill(ride.watts, limit: 5)
        let cad = forwardFill(ride.cadence, limit: 5)
        let pLag = ewmAdjusted(watts, alpha: 1 / emaTau)

        // Steady segment.
        let p60 = rollingMean(watts, window: 60, minPeriods: 30)
        let usable = watts.compactMap { $0 }.filter { $0 > 50 }
        guard !usable.isEmpty else { return nil }
        let med = median(usable)
        let hits = p60.indices.filter { (p60[$0] ?? -1) >= 0.9 * med }
        guard let firstHit = hits.first, let lastHit = hits.last else { return nil }
        let start = max(600, firstHit + 300), end = lastHit
        guard start <= end else { return nil }
        let seg = start...end

        let segCad = seg.map { cad[$0] ?? 0 }
        let hasCadence = Double(segCad.filter { $0 > 0 }.count) / Double(seg.count) > 0.8

        struct Second { let t: Int; let hr: Double; let watts: Double; let pLag: Double; let cadence: Double? }
        var kept: [Second] = []
        for t in seg {
            guard let w = watts[t], w >= 50, let h = hr[t], h >= 60, h <= 200, let p = pLag[t] else { continue }
            if hasCadence { guard let c = cad[t], c >= 50 else { continue } }
            kept.append(Second(t: t, hr: h, watts: w, pLag: p, cadence: cad[t]))
        }
        guard kept.count >= 15 * 60 else { return nil }

        // 30-second bins (means, skipping missing cadence).
        var groups: [Int: [Second]] = [:]
        for s in kept { groups[s.t / binSeconds, default: []].append(s) }
        let bins: [Bin] = groups.sorted { $0.key < $1.key }.map { _, ss in
            let cads = ss.compactMap(\.cadence)
            return Bin(hr: mean(ss.map(\.hr)), watts: mean(ss.map(\.watts)), pLag: mean(ss.map(\.pLag)),
                       cadence: cads.isEmpty ? nil : mean(cads),
                       minutes: mean(ss.map { Double($0.t) / 60 }))
        }
        guard bins.allSatisfy({ $0.hr.isFinite && $0.pLag.isFinite && $0.minutes.isFinite }) else { return nil }
        return PreparedRide(id: ride.id, date: ride.date, bins: bins, hasCadence: hasCadence)
    }

    // MARK: - Fit (within-ride OLS, standard errors clustered by ride)

    static func fit(_ rides: [PreparedRide]) -> Fit? {
        // As in the study: rides without cadence don't inform the fit.
        typealias Row = (hr: Double, pLag: Double, cadence: Double, minutes: Double)
        let groups: [[Row]] = rides.filter(\.hasCadence)
            .map { $0.bins.compactMap { b in b.cadence.map { (b.hr, b.pLag, $0, b.minutes) } } }
            .filter { $0.count >= 2 }
        guard groups.count >= 3 else { return nil }

        // Demean within each ride (equivalent to a baseline per ride).
        var X: [[Double]] = [], y: [Double] = [], cluster: [Int] = []
        for (g, rows) in groups.enumerated() {
            let mh = mean(rows.map(\.hr)), mp = mean(rows.map(\.pLag))
            let mc = mean(rows.map(\.cadence)), mm = mean(rows.map(\.minutes))
            for r in rows {
                X.append([r.pLag - mp, r.minutes - mm, r.cadence - mc])
                y.append(r.hr - mh)
                cluster.append(g)
            }
        }
        // Cadence that never varies within a ride (some trainers report a flat
        // value) carries no information and makes the fit unsolvable, so the
        // fit then uses power and drift only, as for rides without cadence.
        let cadenceVaries = X.contains { abs($0[2]) > 0.5 }
        let k = cadenceVaries ? 3 : 2
        if !cadenceVaries { X = X.map { Array($0.prefix(2)) } }

        let G = Double(groups.count), N = Double(X.count), K = Double(k + groups.count)
        guard N > K + 10 else { return nil }   // enough bins for the fit and its correction

        var xtx = Array(repeating: Array(repeating: 0.0, count: k), count: k)
        var xty = Array(repeating: 0.0, count: k)
        for i in 0..<X.count {
            for a in 0..<k {
                xty[a] += X[i][a] * y[i]
                for b in 0..<k { xtx[a][b] += X[i][a] * X[i][b] }
            }
        }
        guard let inv = invert(xtx) else { return nil }
        let coef = (0..<k).map { a in (0..<k).reduce(0) { $0 + inv[a][$1] * xty[$1] } }

        // Cluster-robust covariance (statsmodels' default small-sample correction;
        // the parameter count includes one baseline per ride).
        var meat = Array(repeating: Array(repeating: 0.0, count: k), count: k)
        var score: [Int: [Double]] = [:]
        for i in 0..<X.count {
            let u = y[i] - (0..<k).reduce(0) { $0 + X[i][$1] * coef[$1] }
            var sc = score[cluster[i]] ?? Array(repeating: 0, count: k)
            for a in 0..<k { sc[a] += X[i][a] * u }
            score[cluster[i]] = sc
        }
        for sc in score.values { for a in 0..<k { for b in 0..<k { meat[a][b] += sc[a] * sc[b] } } }
        let c = G / (G - 1) * (N - 1) / (N - K)
        var cov = Array(repeating: Array(repeating: 0.0, count: k), count: k)
        for a in 0..<k { for b in 0..<k {
            var sum = 0.0
            for i in 0..<k { for j in 0..<k { sum += inv[a][i] * meat[i][j] * inv[j][b] } }
            cov[a][b] = c * sum
        } }
        let se = sqrt(max(cov[0][0], 0))
        let fit = Fit(beta: coef[0], betaLow: coef[0] - 1.959964 * se, betaHigh: coef[0] + 1.959964 * se,
                      cadence: k == 3 ? coef[2] : 0, drift: coef[1], rides: groups.count, bins: X.count)
        // No result rather than a bad one.
        guard [fit.beta, fit.betaLow, fit.betaHigh, fit.cadence, fit.drift].allSatisfy(\.isFinite),
              plausibleBeta.contains(fit.beta) else { return nil }
        return fit
    }

    // MARK: - Watts at the target heart rate

    static func points(_ rides: [PreparedRide], fit: Fit, targetHR: Double) -> [RidePoint] {
        guard plausibleBeta.contains(fit.beta), targetHR.isFinite, targetHR > 0 else { return [] }
        var pts = rides.compactMap { r -> RidePoint? in
            guard !r.bins.isEmpty else { return nil }
            let adj = r.bins.map { b in
                b.hr - fit.beta * (b.pLag - referencePower)
                    - fit.cadence * ((b.cadence ?? referenceCadence) - referenceCadence)
                    - fit.drift * (b.minutes - referenceMinute)
            }
            let watts = referencePower + (targetHR - mean(adj)) / fit.beta
            guard watts.isFinite else { return nil }
            return RidePoint(id: r.id, date: r.date, watts: watts, trend: nil)
        }
        return withTrend(pts)
    }

    /// Watts at the target heart rate from a ride's averages alone: average
    /// heart rate corrected for drift to minute 30 (averages sit at the ride's
    /// midpoint), then converted along β. Rougher than the full data (no
    /// warm-up trim or cadence term): on George's 237 rides it read +3.7 W high
    /// with ±3.6 W scatter, so `offset` (measured on rides that have both) is
    /// subtracted.
    static func summaryPoint(_ r: RideSummary, fit: Fit, targetHR: Double, offset: Double) -> RidePoint? {
        guard plausibleBeta.contains(fit.beta), targetHR.isFinite, offset.isFinite,
              r.averageWatts.isFinite, r.averageWatts > 0, r.averageHR.isFinite, r.averageHR >= 60, r.averageHR <= 200,
              r.durationSeconds.isFinite, r.durationSeconds >= 20 * 60, r.durationSeconds <= Double(maxRideSeconds) else { return nil }
        let hrAt30 = r.averageHR - fit.drift * (r.durationSeconds / 120 - referenceMinute)
        let watts = r.averageWatts + (targetHR - hrAt30) / fit.beta - offset
        guard watts.isFinite else { return nil }
        return RidePoint(id: r.id, date: r.date, watts: watts, trend: nil, isEstimate: true)
    }

    /// Sorted by date, with a 61-day centred rolling median (at least 4 rides
    /// in the window).
    static func withTrend(_ points: [RidePoint]) -> [RidePoint] {
        var pts = points.sorted { $0.date < $1.date }
        let half: TimeInterval = 30.5 * 86_400
        for i in pts.indices {
            let window = pts.filter { abs($0.date.timeIntervalSince(pts[i].date)) <= half }.map(\.watts)
            pts[i].trend = window.count >= 4 ? median(window) : nil
        }
        return pts
    }

    // MARK: - Helpers (match pandas)

    static func forwardFill(_ x: [Double?], limit: Int) -> [Double?] {
        var out = x, last: Double?, gap = 0
        for i in x.indices {
            if let v = x[i] { last = v; gap = 0 }
            else if let l = last, gap < limit { out[i] = l; gap += 1 }
            else { gap += 1 }
        }
        return out
    }

    /// pandas `ewm(alpha:).mean()` with adjust=True, ignore_na=False.
    static func ewmAdjusted(_ x: [Double?], alpha: Double) -> [Double?] {
        var num = 0.0, den = 0.0, seen = false
        return x.map { v in
            num *= (1 - alpha); den *= (1 - alpha)
            if let v { num += v; den += 1; seen = true }
            return seen && den > 0 ? num / den : nil
        }
    }

    static func rollingMean(_ x: [Double?], window: Int, minPeriods: Int) -> [Double?] {
        var out: [Double?] = Array(repeating: nil, count: x.count)
        var sum = 0.0, count = 0
        for i in x.indices {
            if let v = x[i] { sum += v; count += 1 }
            if i >= window, let old = x[i - window] { sum -= old; count -= 1 }
            if count >= minPeriods { out[i] = sum / Double(count) }
        }
        return out
    }

    static func mean(_ x: [Double]) -> Double { x.isEmpty ? .nan : x.reduce(0, +) / Double(x.count) }

    static func median(_ x: [Double]) -> Double {
        let s = x.sorted(), n = s.count
        guard n > 0 else { return .nan }
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// Inverse of a small square matrix (Gauss-Jordan with partial pivoting);
    /// nil if it's singular or anything isn't finite.
    static func invert(_ m: [[Double]]) -> [[Double]]? {
        let n = m.count
        guard n > 0, m.allSatisfy({ $0.count == n && $0.allSatisfy(\.isFinite) }) else { return nil }
        let scale = max(m.indices.map { abs(m[$0][$0]) }.max() ?? 1, 1)
        var a = m, inv = (0..<n).map { i in (0..<n).map { $0 == i ? 1.0 : 0.0 } }
        for col in 0..<n {
            guard let pivot = (col..<n).max(by: { abs(a[$0][col]) < abs(a[$1][col]) }),
                  abs(a[pivot][col]) > 1e-10 * scale else { return nil }
            a.swapAt(col, pivot); inv.swapAt(col, pivot)
            let p = a[col][col]
            for j in 0..<n { a[col][j] /= p; inv[col][j] /= p }
            for r in 0..<n where r != col {
                let f = a[r][col]
                guard f != 0 else { continue }
                for j in 0..<n { a[r][j] -= f * a[col][j]; inv[r][j] -= f * inv[col][j] }
            }
        }
        return inv.allSatisfy({ $0.allSatisfy(\.isFinite) }) ? inv : nil
    }
}
