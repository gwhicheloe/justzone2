import Foundation

struct WorkoutSample: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval  // Offset from workout start
    let heartRate: Int?
    let power: Int?
    let cadence: Int?
    let speed: Double?    // m/s
    let distance: Double  // Cumulative metres from start

    init(timestamp: TimeInterval, heartRate: Int?, power: Int?, cadence: Int?, speed: Double?, distance: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.power = power
        self.cadence = cadence
        self.speed = speed
        self.distance = distance
    }
}
