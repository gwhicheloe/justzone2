import Foundation

/// Removes momentary heart-rate sensor dropouts before they reach the workout.
///
/// Straps and optical sensors occasionally report a single reading, or a few,
/// far below the rider's real heart rate (a lost contact or a dropped beat),
/// then recover. Left alone, one of these dips shows on the live display,
/// nudges Zone Targeting's controller, and is recorded in the workout, Apple
/// Health and the Strava upload.
///
/// A reading more than `dropThreshold` bpm below the average of the recent
/// accepted readings is held at the last good value. If the low reading
/// persists for `persistToAccept` consecutive samples it's real (the rider
/// stopped, say), so it's accepted and the average is reset from there.
/// Values outside a physiological range are always rejected. 0 means "no
/// reading" and passes straight through.
///
/// Same rule as the activity viewer's chart filter (30 bpm below a rolling
/// average), applied once, upstream, to every heart-rate source.
struct HeartRateGlitchFilter {
    static let window = 15            // recent accepted readings to average
    static let minHistory = 5         // don't judge until this many exist
    static let dropThreshold = 30     // bpm below the average to count as a dropout
    static let persistToAccept = 5    // consecutive low readings that make it real
    static let plausible = 30...230   // bpm

    private var recent: [Int] = []
    private var consecutiveLow = 0
    private(set) var rejected = 0

    /// Returns the value to use for this reading: the reading itself, or the
    /// last good value if the reading looks like a dropout.
    mutating func filter(_ bpm: Int) -> Int {
        guard bpm > 0 else { return 0 }

        guard Self.plausible.contains(bpm) else {
            rejected += 1
            return recent.last ?? 0
        }

        if recent.count >= Self.minHistory {
            let average = recent.reduce(0, +) / recent.count
            if bpm < average - Self.dropThreshold {
                consecutiveLow += 1
                if consecutiveLow < Self.persistToAccept {
                    rejected += 1
                    return recent.last ?? bpm
                }
                // Sustained, so it's real: start a fresh baseline from here.
                recent = []
            }
        }

        consecutiveLow = 0
        recent.append(bpm)
        if recent.count > Self.window { recent.removeFirst(recent.count - Self.window) }
        return bpm
    }

    /// Forget the history, e.g. when the heart-rate source changes.
    mutating func reset() {
        recent = []
        consecutiveLow = 0
    }
}
