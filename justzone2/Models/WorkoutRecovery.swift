import Foundation

struct WorkoutRecovery {
    let targetPower: Int
    let targetDuration: TimeInterval
    let elapsedTime: TimeInterval
    let useWatchHR: Bool
    let zoneTargetingEnabled: Bool
    let warmUpEnabled: Bool
}

/// Persists active workout state to UserDefaults so it can be recovered
/// if iOS kills the app mid-workout.
enum WorkoutRecoveryStore {
    private static let prefix = "activeWorkout_"

    static func save(_ r: WorkoutRecovery) {
        let d = UserDefaults.standard
        d.set(true,                    forKey: prefix + "isActive")
        d.set(r.targetPower,           forKey: prefix + "targetPower")
        d.set(r.targetDuration,        forKey: prefix + "targetDuration")
        d.set(r.elapsedTime,           forKey: prefix + "elapsedTime")
        d.set(r.useWatchHR,            forKey: prefix + "useWatchHR")
        d.set(r.zoneTargetingEnabled,  forKey: prefix + "zoneTargetingEnabled")
        d.set(r.warmUpEnabled,         forKey: prefix + "warmUpEnabled")
    }

    static func updateElapsedTime(_ time: TimeInterval) {
        guard UserDefaults.standard.bool(forKey: prefix + "isActive") else { return }
        UserDefaults.standard.set(time, forKey: prefix + "elapsedTime")
    }

    static func load() -> WorkoutRecovery? {
        let d = UserDefaults.standard
        guard d.bool(forKey: prefix + "isActive") else { return nil }
        return WorkoutRecovery(
            targetPower:          d.integer(forKey: prefix + "targetPower"),
            targetDuration:       d.double(forKey:  prefix + "targetDuration"),
            elapsedTime:          d.double(forKey:  prefix + "elapsedTime"),
            useWatchHR:           d.bool(forKey:    prefix + "useWatchHR"),
            zoneTargetingEnabled: d.bool(forKey:    prefix + "zoneTargetingEnabled"),
            warmUpEnabled:        d.bool(forKey:    prefix + "warmUpEnabled")
        )
    }

    static func clear() {
        UserDefaults.standard.set(false, forKey: prefix + "isActive")
    }
}
