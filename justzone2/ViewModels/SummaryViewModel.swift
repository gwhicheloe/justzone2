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

    let workout: Workout
    let stravaService: StravaService

    private var cancellables = Set<AnyCancellable>()

    init(workout: Workout, stravaService: StravaService) {
        self.workout = workout
        self.stravaService = stravaService
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

    func upload() {
        guard uploadState.canTap else { return }

        // Immediate state change - no delay
        uploadState = .processing

        Task {
            let startTime = Date()

            // Do the upload
            var activityId: Int?
            var uploadError: Error?

            do {
                activityId = try await stravaService.uploadWorkout(workout)
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
        // Currently workouts are not persisted locally, so discard just means
        // not uploading to Strava and returning to the setup screen.
        // If local storage is added later, this would delete the workout.
    }
}
