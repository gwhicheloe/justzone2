import ActivityKit
import Foundation

@MainActor
class LiveActivityManager: ObservableObject {
    private var currentActivity: Activity<WorkoutActivityAttributes>?

    @Published var isActivityActive = false

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func startLiveActivity(targetPower: Int, targetDuration: TimeInterval) throws {
        guard areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }

        let attributes = WorkoutActivityAttributes(
            workoutStartDate: Date(),
            targetPower: targetPower,
            targetDuration: targetDuration
        )

        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            currentHeartRate: 0,
            currentPower: 0,
            isPaused: false
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            isActivityActive = true
        } catch {
            throw LiveActivityError.startFailed(error.localizedDescription)
        }
    }

    func updateLiveActivity(elapsedTime: TimeInterval, heartRate: Int, power: Int, isPaused: Bool = false) {
        guard let activity = currentActivity else { return }

        let updatedState = WorkoutActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            currentHeartRate: heartRate,
            currentPower: power,
            isPaused: isPaused
        )

        Task {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
        }
    }

    func endLiveActivity() {
        guard let activity = currentActivity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            currentHeartRate: 0,
            currentPower: 0,
            isPaused: false
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            await MainActor.run {
                self.currentActivity = nil
                self.isActivityActive = false
            }
        }
    }
}

enum LiveActivityError: LocalizedError {
    case notEnabled
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Live Activities are not enabled. Enable them in Settings > JustZone2."
        case .startFailed(let message):
            return "Failed to start Live Activity: \(message)"
        }
    }
}
