import SwiftUI
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [StravaActivity] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isStravaConnected = false
    @Published var lastUpdated: Date?
    @Published var loadingStreamsFor: Int?
    @Published var streamsError: String?

    let stravaService: StravaService
    let streamsCache = StreamsCacheService()

    private var cancellables = Set<AnyCancellable>()
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

    func refreshActivities() async {
        guard isStravaConnected else { return }

        isLoading = true
        error = nil

        do {
            // Fetch all activities from last 3 years
            let allActivities = try await stravaService.fetchAllActivities(years: 3)
            // Filter to only Zone 2 activities
            activities = allActivities.filter { activity in
                activity.name.localizedCaseInsensitiveContains("Zone 2") ||
                activity.name.localizedCaseInsensitiveContains("Zone2") ||
                activity.name.localizedCaseInsensitiveContains("Z2")
            }
            saveToCache()
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refreshActivitiesFromPullDown() async {
        guard isStravaConnected else { return }
        guard !isLoading else { return }

        error = nil

        do {
            // Fetch all activities from last 3 years
            let allActivities = try await stravaService.fetchAllActivities(years: 3)
            activities = allActivities.filter { activity in
                activity.name.localizedCaseInsensitiveContains("Zone 2") ||
                activity.name.localizedCaseInsensitiveContains("Zone2") ||
                activity.name.localizedCaseInsensitiveContains("Z2")
            }
            saveToCache()
        } catch is CancellationError {
            // Ignore cancellation - user released early
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadActivities() async {
        // If we have cached data, don't fetch from Strava
        if !activities.isEmpty {
            return
        }
        await refreshActivities()
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
