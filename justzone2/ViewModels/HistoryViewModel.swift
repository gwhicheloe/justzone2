import SwiftUI
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [StravaActivity] = []
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
    }

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let cached = try? decoder.decode([StravaActivity].self, from: data) {
                activities = cached
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
        guard isStravaConnected else { return }

        dataCleared = false
        isLoading = true
        error = nil

        do {
            let currentYear = Calendar.current.component(.year, from: Date())
            var consecutiveEmptyYears = 0

            for year in stride(from: currentYear, through: currentYear - 10, by: -1) {
                loadingProgress = "Loading \(year)..."

                let yearActivities = try await stravaService.fetchActivitiesForYear(year)
                let zone2 = yearActivities.filter { isZone2Activity($0) }

                if zone2.isEmpty {
                    consecutiveEmptyYears += 1
                } else {
                    consecutiveEmptyYears = 0
                    activities.append(contentsOf: zone2)
                    activities.sort { $0.startDate > $1.startDate }
                    saveToCache()
                }

                // Stop after 2 consecutive empty years
                if consecutiveEmptyYears >= 2 {
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
