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
    /// HR source display name and Zone 2 range captured at workout time, so the
    /// Strava description can be rebuilt on deferred upload. Optional for
    /// backward compatibility with checkpoints saved before these were added.
    var hrSourceName: String?
    var zone2Min: Int?
    var zone2Max: Int?

    var id: UUID { workout.id }
}
