import SwiftUI
import Combine

enum UploadState: Equatable {
    case ready
    case processing
    case complete(activityId: Int)
    case failed(message: String)

    var canTap: Bool {
        switch self {
        case .ready, .failed: return true
        case .processing, .complete: return false
        }
    }
}

@MainActor
class SummaryViewModel: ObservableObject {
    @Published private(set) var uploadState: UploadState = .ready
    @Published var uploadProgress: Double = 0
    @Published var isStravaConnected: Bool = false
    /// Seconds left on the auto-upload countdown (nil when not counting). When it
    /// reaches zero the workout uploads to Strava automatically — so people don't
    /// forget — while leaving a window to Discard or upload immediately.
    @Published private(set) var autoCountdown: Int?

    private var countdownTask: Task<Void, Never>?
    private static let autoUploadSeconds = 10

    let workout: Workout
    let stravaService: StravaService

    /// Workout parameters used to build the Strava activity description.
    let zoneTargetingEnabled: Bool
    let warmUpEnabled: Bool
    let hrSourceName: String
    let zone2Min: Int
    let zone2Max: Int

    private var cancellables = Set<AnyCancellable>()

    init(
        workout: Workout,
        stravaService: StravaService,
        zoneTargetingEnabled: Bool = false,
        warmUpEnabled: Bool = false,
        hrSourceName: String = "HR Strap",
        zone2Min: Int = 120,
        zone2Max: Int = 140
    ) {
        self.workout = workout
        self.stravaService = stravaService
        self.zoneTargetingEnabled = zoneTargetingEnabled
        self.warmUpEnabled = warmUpEnabled
        self.hrSourceName = hrSourceName
        self.zone2Min = zone2Min
        self.zone2Max = zone2Max
        self.isStravaConnected = stravaService.isAuthenticated

        setupBindings()
    }

    private func setupBindings() {
        stravaService.$uploadProgress
            .assign(to: &$uploadProgress)

        stravaService.$isAuthenticated
            .assign(to: &$isStravaConnected)
    }

    func connectToStrava() async {
        do {
            try await stravaService.authenticate()
        } catch {
            uploadState = .failed(message: error.localizedDescription)
        }
    }

    /// Begin the auto-upload countdown. Only for a fresh, connected, not-yet-
    /// uploaded workout. Tapping Upload or Discard cancels it; reaching zero
    /// uploads automatically.
    func startAutoUploadCountdown() {
        guard isStravaConnected, uploadState == .ready, countdownTask == nil else { return }
        autoCountdown = Self.autoUploadSeconds
        countdownTask = Task { @MainActor in
            var remaining = Self.autoUploadSeconds
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
                self.autoCountdown = remaining
            }
            self.autoCountdown = nil
            self.countdownTask = nil
            self.upload()   // time's up — upload automatically
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        autoCountdown = nil
    }

    func upload() {
        guard uploadState.canTap else { return }

        // A manual tap (or the timer firing) ends the countdown.
        cancelCountdown()

        // Immediate state change - no delay
        uploadState = .processing

        Task {
            let startTime = Date()

            // Do the upload
            var activityId: Int?
            var uploadError: Error?

            do {
                let description = StravaService.buildDescription(
                    workout: workout,
                    zoneTargetingEnabled: zoneTargetingEnabled,
                    warmUpEnabled: warmUpEnabled,
                    hrSourceName: hrSourceName,
                    zone2Min: zone2Min,
                    zone2Max: zone2Max
                )
                activityId = try await stravaService.uploadWorkout(workout, description: description)
            } catch {
                uploadError = error
            }

            // Ensure minimum 1.5 seconds of "uploading" state for clear feedback
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 1.5 {
                let remaining = UInt64((1.5 - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: remaining)
            }

            // Update to final state
            if let activityId = activityId {
                uploadState = .complete(activityId: activityId)
                // Strava now has a copy — drop the local file so it doesn't show
                // as pending in History
                LocalWorkoutStore.shared.delete(id: workout.id)
            } else if let error = uploadError {
                uploadState = .failed(message: error.localizedDescription)
            }
        }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var stravaActivityURL: URL? {
        guard case .complete(let activityId) = uploadState else { return nil }
        return URL(string: "https://www.strava.com/activities/\(activityId)")
    }

    func discardWorkout() {
        cancelCountdown()
        LocalWorkoutStore.shared.delete(id: workout.id)
    }
}
