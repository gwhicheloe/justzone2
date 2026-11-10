import Foundation

/// Time-series stream data for a Strava activity
struct ActivityStreams: Codable, Identifiable {
    let activityId: Int
    let fetchedAt: Date
    let time: [Int]         // Seconds from start
    let heartrate: [Int]?   // HR values (bpm)
    let watts: [Int]?       // Power values (watts)
    /// Cadence (rpm). Added Nov 2026 for the normalised history; streams
    /// cached before then don't have it (see `version`).
    var cadence: [Int]? = nil
    /// 2 = fetched with cadence (Nov 2026); nil = older cache, refreshed once
    /// by the normalised-history backfill.
    var version: Int? = nil
    static let currentVersion = 2
    var isComplete: Bool { (version ?? 0) >= Self.currentVersion }

    var id: Int { activityId }

    /// Returns true if this stream has meaningful data to display
    var hasData: Bool {
        !time.isEmpty && (heartrate != nil || watts != nil)
    }

    /// Duration in seconds based on time array
    var duration: Int {
        time.last ?? 0
    }
}
