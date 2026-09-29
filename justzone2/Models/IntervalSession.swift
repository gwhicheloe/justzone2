import Foundation

/// A saved interval workout: a warm-up, `intervalCount` repeats of work and
/// recovery, then a cool-down. Built in the (opt-in) Interval Builder and run
/// in ERG mode — the trainer holds each segment's power, no zone targeting.
struct IntervalSession: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    /// User-supplied name; nil or blank falls back to `defaultName`.
    var customName: String?
    var intervalCount: Int
    var workDuration: TimeInterval
    var workPower: Int
    var restDuration: TimeInterval
    var restPower: Int
    /// Easy riding at `restPower` before the first interval and after the last.
    var warmUpDuration: TimeInterval
    var coolDownDuration: TimeInterval

    static let example = IntervalSession(
        intervalCount: 5, workDuration: 4 * 60, workPower: 220,
        restDuration: 3 * 60, restPower: 120,
        warmUpDuration: 10 * 60, coolDownDuration: 5 * 60
    )

    var name: String {
        if let custom = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return defaultName
    }

    /// e.g. "5 × 4 min @ 220 W" — the whole session in one glance.
    var defaultName: String {
        "\(intervalCount) × \(Self.formatDuration(workDuration)) @ \(workPower) W"
    }

    /// One-line description of the recovery, for detail rows and Strava.
    var recoverySummary: String {
        "\(Self.formatDuration(restDuration)) recovery @ \(restPower) W"
    }

    var segments: [IntervalSegment] {
        var result: [IntervalSegment] = []
        var t: TimeInterval = 0
        func add(_ kind: IntervalSegment.Kind, _ duration: TimeInterval, _ power: Int, _ number: Int) {
            guard duration > 0 else { return }
            result.append(IntervalSegment(kind: kind, start: t, duration: duration, power: power, number: number))
            t += duration
        }
        add(.warmUp, warmUpDuration, restPower, 0)
        for i in 1...max(intervalCount, 1) {
            add(.work, workDuration, workPower, i)
            // No recovery after the last interval — the cool-down follows.
            if i < intervalCount { add(.rest, restDuration, restPower, i) }
        }
        add(.coolDown, coolDownDuration, restPower, 0)
        return result
    }

    var totalDuration: TimeInterval {
        warmUpDuration + coolDownDuration
            + Double(intervalCount) * workDuration
            + Double(max(intervalCount - 1, 0)) * restDuration
    }

    /// The segment in progress at `elapsed` seconds (clamped to the last one).
    func segment(at elapsed: TimeInterval) -> IntervalSegment? {
        let all = segments
        return all.first { elapsed < $0.end } ?? all.last
    }

    /// The next work interval that hasn't started yet at `elapsed`.
    func nextWork(after elapsed: TimeInterval) -> IntervalSegment? {
        segments.first { $0.kind == .work && $0.start > elapsed }
    }

    /// "4 min", "90 s", "1 min 30 s", "1 h 5 min".
    static func formatDuration(_ d: TimeInterval) -> String {
        let s = Int(d.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return m > 0 ? "\(h) h \(m) min" : "\(h) h" }
        if m > 0 { return sec > 0 ? "\(m) min \(sec) s" : "\(m) min" }
        return "\(sec) s"
    }
}

struct IntervalSegment: Equatable {
    enum Kind: String { case warmUp, work, rest, coolDown }
    let kind: Kind
    let start: TimeInterval
    let duration: TimeInterval
    let power: Int
    /// 1-based interval number for work and rest segments; 0 otherwise.
    let number: Int
    var end: TimeInterval { start + duration }
    var isWork: Bool { kind == .work }
}

/// Persists the saved interval sessions and whether the feature is switched
/// on. Sessions are tiny, so UserDefaults (JSON) is plenty.
@MainActor
final class IntervalSessionStore: ObservableObject {
    static let shared = IntervalSessionStore()

    /// Settings toggle. Off by default: the app stays a Zone 2 app unless the
    /// rider opts in.
    static let enabledKey = "intervalBuilderEnabled"
    private static let sessionsKey = "intervalSessions"

    @Published private(set) var sessions: [IntervalSession] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.sessionsKey),
           let decoded = try? JSONDecoder().decode([IntervalSession].self, from: data) {
            sessions = decoded
        }
    }

    func session(id: UUID?) -> IntervalSession? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    func save(_ session: IntervalSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        persist()
    }

    func delete(id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.sessionsKey)
        }
    }
}
