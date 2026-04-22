import Foundation

/// A workout persisted to disk. Can be either an in-progress checkpoint
/// (recoverable if the app dies mid-workout) or a completed workout that
/// hasn't been uploaded to Strava yet.
struct LocalWorkout: Codable, Identifiable {
    enum Status: String, Codable {
        case inProgress
        case pendingUpload
    }

    var workout: Workout
    let useWatchHR: Bool
    let zoneTargetingEnabled: Bool
    let warmUpEnabled: Bool
    var elapsedTime: TimeInterval
    var status: Status
    var lastCheckpoint: Date

    var id: UUID { workout.id }
}
