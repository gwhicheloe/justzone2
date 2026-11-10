import Foundation

/// Normalised Zone 2 history for the History tab: each Zone 2 ride's power at
/// the rider's Zone 2 target heart rate (see `HRNormalisation`), from the
/// rider's own heart-rate-per-watt slope fitted across their Zone 2 rides.
///
/// Data: the full second-by-second streams of each Zone 2 ride, kept on the
/// phone in `StreamsCacheService`.
/// - Rides recorded in JustZone2 are saved there when they're uploaded, from
///   the ride's own samples: no Strava request.
/// - Older rides (and Zwift ones) are backfilled from Strava gently, because
///   Strava's rate limit is shared by every rider of the app: newest first, at
///   most `dailyLimit` a day, never fetched twice, stopping for the day on a
///   rate-limit response.
///
/// The analysis runs off the main thread and is never trusted blindly: the
/// view is offered only once there's enough data and the slope is confident.
@MainActor
final class NormalisedHistoryService: ObservableObject {
    /// Rides whose full data is on the phone (for the list's subtle marker).
    @Published private(set) var completeIDs: Set<Int> = []
    /// The ride being downloaded right now, if any (the list shows a spinner).
    @Published private(set) var downloadingID: Int?
    @Published private(set) var points: [HRNormalisation.RidePoint] = []
    @Published private(set) var fit: HRNormalisation.Fit?
    @Published private(set) var targetHR: Int = 0
    @Published private(set) var isReady = false
    /// Why it isn't ready yet, in words ("Needs 3 more rides with full data").
    @Published private(set) var status = ""

    /// Ride downloads per rider per day. Each is one of Strava's non-upload
    /// requests, limited for the whole app (all riders together) to 1,000 a
    /// day and 100 per 15 minutes by default (2,000 / 200 at the 10-athlete
    /// tier). 20 a day is 2% of the daily limit per rider; the batch lands in
    /// one 15-minute window (20% of it by default) whatever the spacing, so a
    /// 429 stops the backfill for the day.
    static let dailyLimit = 20
    static let spacingSeconds: UInt64 = 10
    static let minRides = 8
    static let minSpanDays = 28.0
    /// Slope must be known to within this (half the 95% range), bpm per watt.
    static let maxBetaHalfWidth = 0.1

    private let stravaService: StravaService
    private let cache: StreamsCacheService
    private var analysing = false
    /// A refresh asked for mid-calculation; runs as soon as it finishes.
    private var pending: (activities: [StravaActivity], locals: [LocalWorkout])?
    private var backfilling = false

    private static let dayKey = "normalisedBackfillDay"
    private static let countKey = "normalisedBackfillCount"
    private static let pausedKey = "normalisedBackfillPausedDay"

    init(stravaService: StravaService, cache: StreamsCacheService) {
        self.stravaService = stravaService
        self.cache = cache
    }

    // MARK: - Analysis

    /// Recompute from what's on the phone. Cheap to call; runs in the background.
    func refresh(activities: [StravaActivity], localWorkouts: [LocalWorkout]) {
        guard !analysing else { pending = (activities, localWorkouts); return }
        analysing = true
        let target = Int(Zone2Target.bpm(zoneMin: Self.zone2Min, zoneMax: Self.zone2Max).rounded())
        let cache = self.cache
        let candidates = activities.filter { !$0.name.hasPrefix("Intervals:") }
        let locals = localWorkouts.filter { !$0.workout.isIntervalSession && $0.workout.samples.count > 15 * 60 }

        Task {
            // Load what's cached (actor-isolated file reads).
            var rides: [HRNormalisation.Ride] = []
            var complete = Set<Int>()
            var summaries: [HRNormalisation.RideSummary] = []
            for a in candidates {
                if let s = await cache.loadStreams(for: a.id) {
                    if s.isComplete { complete.insert(a.id) }
                    if let r = Self.ride(from: s, date: a.startDate) { rides.append(r) }
                }
                if let w = a.averageWatts, let h = a.averageHeartrate {
                    summaries.append(.init(id: String(a.id), date: a.startDate, averageWatts: w, averageHR: h,
                                           durationSeconds: Double(a.movingTime)))
                }
            }
            let rideSnapshot = rides, summarySnapshot = summaries
            for l in locals {
                if let r = Self.ride(from: l.workout) { rides.append(r) }
            }

            // The maths, off the main thread.
            let result = await Task.detached(priority: .utility) { () -> (HRNormalisation.Fit?, [HRNormalisation.RidePoint], Int) in
                let prepared = rideSnapshot.compactMap(HRNormalisation.prepare)
                guard let fit = HRNormalisation.fit(prepared) else { return (nil, [], prepared.count) }
                let full = HRNormalisation.points(prepared, fit: fit, targetHR: Double(target))
                // Early view: rides without full data are estimated from their
                // averages, with the averages' offset measured on rides that
                // have both removed (0 until there are at least 3).
                let fullByID = Dictionary(full.map { ($0.id, $0.watts) }, uniquingKeysWith: { a, _ in a })
                let raw = summarySnapshot.compactMap { HRNormalisation.summaryPoint($0, fit: fit, targetHR: Double(target), offset: 0) }
                let diffs = raw.compactMap { p in fullByID[p.id].map { p.watts - $0 } }
                let offset = diffs.count >= 3 ? HRNormalisation.median(diffs) : 0
                let estimates = summarySnapshot
                    .filter { fullByID[$0.id] == nil }
                    .compactMap { HRNormalisation.summaryPoint($0, fit: fit, targetHR: Double(target), offset: offset) }
                return (fit, HRNormalisation.withTrend(full + estimates), prepared.count)
            }.value

            self.completeIDs = complete
            self.targetHR = target
            self.fit = result.0
            self.points = result.1
            self.evaluate(usableRides: result.2)
            self.analysing = false
            if let next = self.pending {
                self.pending = nil
                self.refresh(activities: next.activities, localWorkouts: next.locals)
            }
            if let f = result.0 {
                dlog(String(format: "[NORM] %d rides usable, %d with full data, β %.3f [%.3f–%.3f] bpm/W, target %d bpm (Zone 2 %d–%d, %.2f), ready=%@",
                            result.2, complete.count, f.beta, f.betaLow, f.betaHigh, target, Self.zone2Min, Self.zone2Max, Zone2Target.fraction, self.isReady ? "yes" : "no"))
            } else {
                dlog("[NORM] \(result.2) rides usable, no fit yet")
            }
        }
    }

    private func evaluate(usableRides: Int) {
        guard let fit else {
            isReady = false
            let more = max(0, Self.minRides - usableRides)
            status = more > 0
                ? "Needs \(more) more Zone 2 \(more == 1 ? "ride" : "rides") with full data."
                : "Still learning how your heart rate responds to power."
            return
        }
        let span = (points.last?.date.timeIntervalSince(points.first?.date ?? Date()) ?? 0) / 86_400
        if points.count < Self.minRides {
            let more = Self.minRides - points.count
            status = "Needs \(more) more Zone 2 \(more == 1 ? "ride" : "rides") with full data."
            isReady = false
        } else if span < Self.minSpanDays {
            status = "Needs rides spread over at least four weeks."
            isReady = false
        } else if fit.betaHalfWidth > Self.maxBetaHalfWidth {
            status = "Still learning how your heart rate responds to power."
            isReady = false
        } else {
            status = ""
            isReady = true
        }
    }

    // MARK: - Backfill (gentle on Strava's shared rate limit)

    /// Fetch full data for up to today's remaining allowance of Zone 2 rides
    /// that don't have it, newest first. Returns true if anything new arrived.
    @discardableResult
    func backfill(activities: [StravaActivity], onBatch: (() -> Void)? = nil) async -> Bool {
        guard !backfilling else { dlog("[NORM] backfill skipped: already running"); return false }
        guard stravaService.isAuthenticated else { dlog("[NORM] backfill skipped: Strava not connected"); return false }
        let today = Self.dayString()
        let d = UserDefaults.standard
        if d.string(forKey: Self.pausedKey) == today { dlog("[NORM] backfill skipped: paused for today"); return false }
        if d.string(forKey: Self.dayKey) != today { d.set(today, forKey: Self.dayKey); d.set(0, forKey: Self.countKey) }
        var used = d.integer(forKey: Self.countKey)
        guard used < Self.dailyLimit else { dlog("[NORM] backfill skipped: \(used)/\(Self.dailyLimit) already today"); return false }

        backfilling = true
        defer { backfilling = false }
        var fetched = 0
        let todo = activities
            .filter { !$0.name.hasPrefix("Intervals:") && $0.averageHeartrate != nil && $0.averageWatts != nil }
            .sorted { $0.startDate > $1.startDate }
        dlog("[NORM] backfill starting: \(todo.count) candidate rides, \(Self.dailyLimit - used) allowed today")
        for a in todo {
            guard used < Self.dailyLimit else { break }
            if let s = await cache.loadStreams(for: a.id), s.isComplete { continue }
            downloadingID = a.id
            defer { downloadingID = nil }
            do {
                let s = try await stravaService.fetchActivityStreams(activityId: a.id)
                await cache.saveStreams(s)
                completeIDs.insert(a.id)
                fetched += 1
                if fetched % 5 == 0 { onBatch?() }   // update the chart as rides arrive
            } catch StravaError.rateLimited {
                d.set(today, forKey: Self.pausedKey)
                dlog("[NORM] backfill paused for today: Strava rate limit")
                break
            } catch StravaError.streamsNotAvailable {
                // Nothing to fetch for this one (e.g. a manual activity): mark it
                // complete-but-empty so it isn't asked for again.
                await cache.saveStreams(ActivityStreams(activityId: a.id, fetchedAt: Date(), time: [], heartrate: nil, watts: nil,
                                                        cadence: nil, version: ActivityStreams.currentVersion))
            } catch {
                dlog("[NORM] backfill stopped: \(error.localizedDescription)")
                break
            }
            used += 1
            d.set(used, forKey: Self.countKey)
            try? await Task.sleep(nanoseconds: Self.spacingSeconds * 1_000_000_000)   // spread out: never a burst
        }
        if fetched > 0 { dlog("[NORM] backfilled \(fetched) rides (\(used)/\(Self.dailyLimit) today)") }
        return fetched > 0
    }

    // MARK: - Rides recorded in the app

    /// Keep a ride's full data on the phone under its new Strava activity ID,
    /// straight from the ride's own samples (no Strava request needed later).
    static func saveUploadedRide(_ workout: Workout, activityId: Int, cache: StreamsCacheService) async {
        guard !workout.samples.isEmpty else { return }
        let time = workout.samples.map { max(0, Int($0.timestamp.rounded())) }
        let streams = ActivityStreams(
            activityId: activityId, fetchedAt: Date(), time: time,
            heartrate: workout.samples.map { $0.heartRate ?? 0 },
            watts: workout.samples.map { $0.power ?? 0 },
            cadence: workout.samples.map { $0.cadence ?? 0 },
            version: ActivityStreams.currentVersion)
        await cache.saveStreams(streams)
    }

    // MARK: - Conversions (all through the engine's validated entry point)

    nonisolated static func ride(from s: ActivityStreams, date: Date) -> HRNormalisation.Ride? {
        guard let hr = s.heartrate, let w = s.watts, !s.time.isEmpty else { return nil }
        func opt(_ x: [Int]) -> [Double?] { x.map { $0 > 0 ? Double($0) : nil } }
        return HRNormalisation.ride(id: String(s.activityId), date: date, time: s.time,
                                    hr: opt(hr), watts: w.map { Double($0) }, cadence: s.cadence.map(opt))
    }

    nonisolated static func ride(from w: Workout) -> HRNormalisation.Ride? {
        let time = w.samples.map { $0.timestamp.isFinite ? Int(min(max($0.timestamp, -1), 1e7).rounded()) : -1 }
        return HRNormalisation.ride(id: w.id.uuidString, date: w.startDate, time: time,
                                    hr: w.samples.map { $0.heartRate.flatMap { $0 > 0 ? Double($0) : nil } },
                                    watts: w.samples.map { $0.power.map(Double.init) },
                                    cadence: w.samples.map { $0.cadence.flatMap { $0 > 0 ? Double($0) : nil } })
    }

    private static var zone2Min: Int { let v = UserDefaults.standard.integer(forKey: "zone2Min"); return v > 0 ? v : 120 }
    private static var zone2Max: Int { let v = UserDefaults.standard.integer(forKey: "zone2Max"); return v > 0 ? v : 140 }

    private static func dayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}
