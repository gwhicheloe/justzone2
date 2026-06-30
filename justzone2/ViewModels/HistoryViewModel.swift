import SwiftUI
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [StravaActivity] = []
    @Published var localWorkouts: [LocalWorkout] = []
    @Published var isLoading = false
    @Published var loadingProgress: String?
    @Published var error: String?
    @Published var isStravaConnected = false
    @Published var lastUpdated: Date?
    @Published var loadingStreamsFor: Int?
    @Published var streamsError: String?

    let stravaService: StravaService
    let streamsCache = StreamsCacheService()

    private var cancellables = Set<AnyCancellable>()
    private var dataCleared = false
    private let cacheKey = "cachedActivities"
    private let lastUpdatedKey = "activitiesLastUpdated"

    init(stravaService: StravaService) {
        self.stravaService = stravaService
        self.isStravaConnected = stravaService.isAuthenticated

        stravaService.$isAuthenticated
            .assign(to: &$isStravaConnected)

        // Load cached activities
        loadFromCache()
        loadLocalWorkouts()
    }

    /// Reload local workouts from disk. Call after upload completes or
    /// when entering History so the pending list reflects current state.
    func loadLocalWorkouts() {
        localWorkouts = LocalWorkoutStore.shared.all()
    }

    // MARK: - Demo Mode

    /// True while Demo Mode is showing seeded sample rides instead of real data.
    private(set) var demoHistoryActive = false

    /// Populate History with a handful of believable Zone 2 rides so the tab
    /// isn't empty in Demo Mode. Driven by `AppState.applyDemoMode`.
    func loadDemoHistory() {
        demoHistoryActive = true
        error = nil
        isLoading = false
        localWorkouts = []
        activities = DemoActivityProvider.activities
    }

    /// Leave Demo Mode — restore the real cached activities and pending list.
    func clearDemoHistory() {
        demoHistoryActive = false
        loadFromCache()
        loadLocalWorkouts()
    }

    /// Upload a local workout to Strava. On success, removes the local
    /// file and triggers a refresh so the activity shows up under Strava.
    /// Returns the new Strava activity ID, or nil on failure.
    @discardableResult
    func uploadLocalWorkout(_ local: LocalWorkout) async -> Int? {
        do {
            let description = StravaService.buildDescription(
                workout: local.workout,
                zoneTargetingEnabled: local.zoneTargetingEnabled,
                warmUpEnabled: local.warmUpEnabled,
                hrSourceName: local.hrSourceName ?? (local.useWatchHR ? "Apple Watch" : "HR Strap"),
                zone2Min: local.zone2Min ?? 120,
                zone2Max: local.zone2Max ?? 140
            )
            let activityId = try await stravaService.uploadWorkout(local.workout, description: description)
            LocalWorkoutStore.shared.delete(id: local.id)
            loadLocalWorkouts()
            return activityId
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteLocalWorkout(_ local: LocalWorkout) {
        LocalWorkoutStore.shared.delete(id: local.id)
        loadLocalWorkouts()
    }

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let cached = try? decoder.decode([StravaActivity].self, from: data) {
                activities = cached
                deduplicateActivities()
            }
        }
        if let date = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date {
            lastUpdated = date
        }
    }

    private func saveToCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(activities) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastUpdatedKey)
            lastUpdated = Date()
        }
    }

    /// Initial full download — fetches year by year with progress
    func refreshActivities() async {
        guard !demoHistoryActive else { return }
        guard isStravaConnected else { return }

        dataCleared = false
        isLoading = true
        error = nil

        do {
            let currentYear = Calendar.current.component(.year, from: Date())
            var consecutiveEmptyYears = 0

            for year in stride(from: currentYear, through: currentYear - 20, by: -1) {
                loadingProgress = "Loading \(year)..."

                let yearActivities = try await stravaService.fetchActivitiesForYear(year)
                let zone2 = yearActivities.filter { isZone2Activity($0) }

                if zone2.isEmpty {
                    consecutiveEmptyYears += 1
                } else {
                    consecutiveEmptyYears = 0
                    activities.append(contentsOf: zone2)
                    deduplicateActivities()
                    activities.sort { $0.startDate > $1.startDate }
                    saveToCache()
                }

                // Stop after 5 consecutive empty years — allows for multi-year gaps
                if consecutiveEmptyYears >= 5 {
                    break
                }
            }

            // Deduplicate by ID (in case of overlap)
            deduplicateActivities()
            saveToCache()
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            self.error = error.localizedDescription
        }

        loadingProgress = nil
        isLoading = false
    }

    /// Incremental refresh — only fetches activities since the most recent cached one
    func refreshActivitiesFromPullDown() async {
        guard !demoHistoryActive else { return }
        guard isStravaConnected else { return }
        guard !isLoading else { return }

        // If no cached data, do a full download instead
        guard !activities.isEmpty else {
            await refreshActivities()
            return
        }

        isLoading = true
        error = nil

        do {
            // Fetch from 1 month before the latest activity to catch any gaps
            let latestDate = activities.first?.startDate ?? Date()
            let fetchFrom = Calendar.current.date(byAdding: .month, value: -1, to: latestDate) ?? latestDate

            let recentActivities = try await stravaService.fetchActivitiesSince(fetchFrom)

            // Build a lookup of all fetched IDs so we can detect renames
            let fetchedById = Dictionary(uniqueKeysWithValues: recentActivities.map { ($0.id, $0) })

            // Merge by ID — update existing, add new Zone 2, remove renamed non-Zone 2
            var activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
            for (id, activity) in fetchedById {
                if isZone2Activity(activity) {
                    activityMap[id] = activity
                } else {
                    activityMap.removeValue(forKey: id)
                }
            }

            activities = activityMap.values.sorted { $0.startDate > $1.startDate }
            saveToCache()
        } catch is CancellationError {
            // Ignore cancellation - user released early
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadActivities() async {
        // If we have cached data or user just cleared data, don't auto-fetch
        if !activities.isEmpty || dataCleared {
            return
        }
        await refreshActivities()
    }

    func clearAllData() async {
        activities = []
        dataCleared = true
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: lastUpdatedKey)
        lastUpdated = nil
        await streamsCache.clearCache()
    }

    private func isZone2Activity(_ activity: StravaActivity) -> Bool {
        activity.name.localizedCaseInsensitiveContains("Zone 2") ||
        activity.name.localizedCaseInsensitiveContains("Zone2") ||
        activity.name.localizedCaseInsensitiveContains("Z2")
    }

    private func deduplicateActivities() {
        var seen = Set<Int>()
        activities = activities.filter { seen.insert($0.id).inserted }
    }

    func connectToStrava() async {
        do {
            try await stravaService.authenticate()
        } catch {
            // ASWebAuthenticationSession error 1 = user cancelled — not an error
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
                return
            }
            self.error = error.localizedDescription
        }
    }

    func disconnectStrava() {
        stravaService.logout()
        activities = []
        error = nil
    }

    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    func formatDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yy HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Stream Loading

    /// Check if streams are cached for an activity
    func hasStreams(for activityId: Int) async -> Bool {
        await streamsCache.hasStreams(for: activityId)
    }

    /// Load streams for an activity - checks cache first, fetches from Strava if missing
    func loadStreams(for activity: StravaActivity) async -> ActivityStreams? {
        // Demo rides have synthetic streams — never hit the cache or network.
        if demoHistoryActive {
            return DemoActivityProvider.streams(for: activity)
        }

        // Check cache first
        if let cached = await streamsCache.loadStreams(for: activity.id) {
            return cached
        }

        // Fetch from Strava
        loadingStreamsFor = activity.id
        streamsError = nil

        do {
            let streams = try await stravaService.fetchActivityStreams(activityId: activity.id)
            await streamsCache.saveStreams(streams)
            loadingStreamsFor = nil
            return streams
        } catch StravaError.streamsNotAvailable {
            streamsError = "Stream data not available for this activity"
            loadingStreamsFor = nil
            return nil
        } catch {
            streamsError = error.localizedDescription
            loadingStreamsFor = nil
            return nil
        }
    }
}

// MARK: - Demo Mode sample data

/// Seeds History with believable Zone 2 rides (and matching HR/power streams) so
/// the tab — and the activity-detail charts — can be explored without hardware or
/// a Strava account. The streams are deterministic per activity, so reopening a
/// ride always shows the same chart.
enum DemoActivityProvider {
    static var activities: [StravaActivity] {
        let now = Date()
        let cal = Calendar.current
        // (id, name, days ago, hour, minutes, avg watts, avg HR, max HR)
        let specs: [(Int, String, Int, Int, Int, Double, Double, Double)] = [
            (9_000_001, "Zone 2 Endurance",     2,  7, 60, 168, 134, 148),
            (9_000_002, "Z2 Recovery Spin",     4, 18, 40, 142, 126, 138),
            (9_000_003, "Zone 2 Base Builder",  7,  6, 75, 172, 138, 151),
            (9_000_004, "Zone 2 Aerobic",      12, 19, 55, 160, 132, 145),
            (9_000_005, "Z2 Long Ride",        17,  9, 90, 165, 136, 150),
        ]
        return specs.map { id, name, daysAgo, hour, minutes, avgW, avgHR, maxHR in
            let secs = minutes * 60
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
            return StravaActivity(
                id: id,
                name: name,
                type: "VirtualRide",
                startDate: start,
                movingTime: secs,
                distance: Double(secs) * 7.6,   // ~27 km/h average
                averageWatts: avgW,
                averageHeartrate: avgHR,
                maxHeartrate: maxHR
            )
        }
    }

    static func streams(for activity: StravaActivity) -> ActivityStreams {
        let dur = activity.movingTime
        let avgHR = activity.averageHeartrate ?? 134
        let avgW = activity.averageWatts ?? 165
        let off = Double(activity.id % 7)
        var time: [Int] = []
        var hr: [Int] = []
        var watts: [Int] = []
        var t = 0
        while t <= dur {
            let td = Double(t)
            let ramp = min(1.0, td / 180.0)   // ease up over the first 3 minutes
            let h = avgHR * (0.86 + 0.14 * ramp) + 6 * sin(td / 120 + off) + 3 * sin(td / 37)
            let w = avgW * (0.70 + 0.30 * ramp) + 12 * sin(td / 90 + off) + 5 * sin(td / 23)
            time.append(t)
            hr.append(Int(h.rounded()))
            watts.append(Int(max(0, w).rounded()))
            t += 10
        }
        return ActivityStreams(activityId: activity.id, fetchedAt: Date(), time: time, heartrate: hr, watts: watts)
    }
}
