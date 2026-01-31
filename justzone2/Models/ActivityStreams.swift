import Foundation

/// Time-series stream data for a Strava activity
struct ActivityStreams: Codable, Identifiable {
    let activityId: Int
    let fetchedAt: Date
    let time: [Int]         // Seconds from start
    let heartrate: [Int]?   // HR values (bpm)
    let watts: [Int]?       // Power values (watts)

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
