import Foundation

struct WorkoutSample: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval  // Offset from workout start
    let heartRate: Int?
    let power: Int?

    init(timestamp: TimeInterval, heartRate: Int?, power: Int?) {
        self.id = UUID()
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.power = power
    }
}
