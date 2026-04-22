import Foundation

/// Persists workouts as JSON files in `Documents/workouts/`.
/// One file per workout, named `{uuid}.json`. Atomic writes prevent
/// corruption if the process is killed mid-write.
final class LocalWorkoutStore {
    static let shared = LocalWorkoutStore()

    private let dir: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    init(directory: URL? = nil) {
        if let directory {
            self.dir = directory
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.dir = docs.appendingPathComponent("workouts", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    private func url(for id: UUID) -> URL {
        dir.appendingPathComponent("\(id.uuidString).json")
    }

    @discardableResult
    func save(_ lw: LocalWorkout) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        do {
            let data = try encoder.encode(lw)
            try data.write(to: url(for: lw.id), options: [.atomic])
            return true
        } catch {
            dlog("[LocalWorkoutStore] save failed: \(error.localizedDescription)")
            return false
        }
    }

    func load(id: UUID) -> LocalWorkout? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return try? decoder.decode(LocalWorkout.self, from: data)
    }

    func all() -> [LocalWorkout] {
        lock.lock()
        defer { lock.unlock() }
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        let workouts = files.compactMap { url -> LocalWorkout? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(LocalWorkout.self, from: data)
        }
        return workouts.sorted { $0.workout.startDate > $1.workout.startDate }
    }

    /// Most recent in-progress workout, if any. Used by SetupView to offer recovery.
    func mostRecentInProgress() -> LocalWorkout? {
        all().first { $0.status == .inProgress }
    }

    func delete(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
