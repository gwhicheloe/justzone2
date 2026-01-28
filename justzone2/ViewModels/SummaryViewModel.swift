import SwiftUI
import Combine

enum UploadState {
    case idle
    case uploading
    case success(activityId: Int)
    case error(String)
}

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var uploadState: UploadState = .idle
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
            uploadState = .error(error.localizedDescription)
        }
    }

    func uploadToStrava() async {
        // Prevent double upload
        guard case .idle = uploadState else {
            print("Upload blocked - not in idle state: \(uploadState)")
            return
        }

        print("Starting upload...")
        uploadState = .uploading

        do {
            let activityId = try await stravaService.uploadWorkout(workout)
            print("Upload successful! Activity ID: \(activityId)")
            uploadState = .success(activityId: activityId)
        } catch {
            print("Upload failed: \(error.localizedDescription)")
            uploadState = .error(error.localizedDescription)
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
        guard case .success(let activityId) = uploadState else { return nil }
        return URL(string: "https://www.strava.com/activities/\(activityId)")
    }

    func resetUploadState() {
        uploadState = .idle
    }

    func discardWorkout() {
        // Currently workouts are not persisted locally, so discard just means
        // not uploading to Strava and returning to the setup screen.
        // If local storage is added later, this would delete the workout.
    }
}
