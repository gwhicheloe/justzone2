import Foundation

/// Decides when to ask for an App Store rating.
///
/// Ratings are what make a stranger trust a paid app, so we ask — but only once
/// a rider has had a real experience of it: after their second completed ride,
/// counting only real rides of at least 15 minutes (Demo Mode and quick pairing
/// tests don't count). We ask at most once per app version, and the system
/// prompt itself is rate-limited by iOS (never more than three times a year),
/// so this can't nag.
enum ReviewPrompt {
    static let ridesBeforeAsking = 2
    static let minimumRide: TimeInterval = 15 * 60

    private static let rideCountKey = "reviewPromptCompletedRides"
    private static let askedVersionKey = "reviewPromptAskedVersion"

    /// Call when a workout finishes.
    static func recordCompletedRide(duration: TimeInterval, isDemo: Bool) {
        guard !isDemo, duration >= minimumRide else { return }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: rideCountKey) + 1, forKey: rideCountKey)
    }

    /// True when it's time to ask: enough real rides, and not yet asked in this
    /// version. Marks the version as asked, so it returns true at most once.
    static func consumeShouldAsk() -> Bool {
        let defaults = UserDefaults.standard
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard defaults.integer(forKey: rideCountKey) >= ridesBeforeAsking,
              defaults.string(forKey: askedVersionKey) != version else { return false }
        defaults.set(version, forKey: askedVersionKey)
        return true
    }
}
