import Foundation

struct Workout: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    let targetPower: Int
    let targetDuration: TimeInterval
    var samples: [WorkoutSample]

    init(targetPower: Int, targetDuration: TimeInterval) {
        self.id = UUID()
        self.startDate = Date()
        self.endDate = nil
        self.targetPower = targetPower
        self.targetDuration = targetDuration
        self.samples = []
    }

    var actualDuration: TimeInterval {
        guard let endDate = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return endDate.timeIntervalSince(startDate)
    }

    var averageHeartRate: Int? {
        let hrSamples = samples.compactMap { $0.heartRate }
        guard !hrSamples.isEmpty else { return nil }
        return hrSamples.reduce(0, +) / hrSamples.count
    }

    var maxHeartRate: Int? {
        samples.compactMap { $0.heartRate }.max()
    }

    var averagePower: Int? {
        let powerSamples = samples.compactMap { $0.power }
        guard !powerSamples.isEmpty else { return nil }
        return powerSamples.reduce(0, +) / powerSamples.count
    }

    var maxPower: Int? {
        samples.compactMap { $0.power }.max()
    }

    mutating func addSample(heartRate: Int?, power: Int?) {
        let timestamp = Date().timeIntervalSince(startDate)
        let sample = WorkoutSample(timestamp: timestamp, heartRate: heartRate, power: power)
        samples.append(sample)
    }

    mutating func finish() {
        endDate = Date()
    }
}
