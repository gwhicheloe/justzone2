import Foundation

/// The heart-rate source for a workout. Three flows currently exist:
///
/// - `.appleWatch`: iPhone wakes the Watch app via `startWatchApp(.indoor)`,
///   Watch reads HR from its own session and ships samples over WCSession.
/// - `.airPods`: AirPods Pro 3+ in-ear PPG. iOS pushes HR samples into the
///   HealthKit store; the iPhone's `HKLiveWorkoutBuilder` auto-collects them
///   via `workoutBuilder(_:didCollectDataOf:)`. Requires an active workout
///   session on iOS.
/// - `.bleStrap`: a BLE HR strap (e.g. Polar H10, Wahoo TICKR) connected
///   directly to iPhone via Core Bluetooth, streamed through `HeartRateService`.
enum HRSource: String, Codable, CaseIterable, Identifiable {
    case appleWatch
    case airPods
    case bleStrap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .airPods:    return "AirPods Pro"
        case .bleStrap:   return "HR Strap"
        }
    }

    /// True if this source requires the Watch app to be launched and running.
    var requiresWatchApp: Bool { self == .appleWatch }

    /// True if HR samples flow into the iPhone HKLiveWorkoutBuilder natively
    /// (no manual `addHeartRateSample` calls needed).
    var writesToBuilderNatively: Bool { self == .airPods }
}
