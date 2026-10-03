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
    /// Sets: repeat the block of `intervalCount` intervals `setCount` times,
    /// with a longer recovery (at `restPower`) between sets — e.g. Rønnestad's
    /// 3 × 13 × 30/15. Off by default; when off a session is a single set.
    var setsEnabled = false
    var setCount = 3
    var setRecoveryDuration: TimeInterval = 180

    /// Starting point for "New Session". Computed, not a stored `static let`:
    /// a stored template kept one UUID for the whole app run, so every new
    /// session shared an id and saving one overwrote the last.
    static var newTemplate: IntervalSession {
        IntervalSession(
            intervalCount: 5, workDuration: 4 * 60, workPower: 220,
            restDuration: 3 * 60, restPower: 120,
            warmUpDuration: 5 * 60, coolDownDuration: 5 * 60
        )
    }

    /// Number of sets actually ridden (1 when sets are off).
    var sets: Int { setsEnabled ? max(setCount, 1) : 1 }

    /// Work intervals in the whole session.
    var totalIntervals: Int { intervalCount * sets }

    /// The session's structure: "5 × 4 min" or "3 × 13 × 30 s".
    var structure: String {
        let reps = "\(intervalCount) × \(Self.formatDuration(workDuration))"
        return setsEnabled ? "\(sets) × \(reps)" : reps
    }

    /// "Interval 3 of 13", or "Set 2 · interval 3 of 13" when sets are on.
    func intervalLabel(_ segment: IntervalSegment) -> String {
        setsEnabled
            ? "Set \(segment.set) of \(sets) · interval \(segment.number) of \(intervalCount)"
            : "Interval \(segment.number) of \(intervalCount)"
    }

    var name: String {
        if let custom = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return defaultName
    }

    /// e.g. "5 × 4 min @ 220 W" — the whole session in one glance.
    var defaultName: String {
        "\(structure) @ \(workPower) W"
    }

    /// One-line description of the recovery, for detail rows and Strava.
    var recoverySummary: String {
        "\(Self.formatDuration(restDuration)) recovery @ \(restPower) W"
    }

    var segments: [IntervalSegment] {
        var result: [IntervalSegment] = []
        var t: TimeInterval = 0
        func add(_ kind: IntervalSegment.Kind, _ duration: TimeInterval, _ power: Int, _ number: Int, _ set: Int) {
            guard duration > 0 else { return }
            result.append(IntervalSegment(kind: kind, start: t, duration: duration, power: power, number: number, set: set))
            t += duration
        }
        add(.warmUp, warmUpDuration, restPower, 0, 0)
        let reps = max(intervalCount, 1)
        for set in 1...sets {
            for i in 1...reps {
                add(.work, workDuration, workPower, i, set)
                // No short recovery after a set's last interval: the set
                // recovery (or, after the last set, the cool-down) follows.
                if i < reps { add(.rest, restDuration, restPower, i, set) }
            }
            if set < sets { add(.setRest, setRecoveryDuration, restPower, 0, set) }
        }
        add(.coolDown, coolDownDuration, restPower, 0, 0)
        return result
    }

    var totalDuration: TimeInterval {
        let perSet = Double(intervalCount) * workDuration + Double(max(intervalCount - 1, 0)) * restDuration
        return warmUpDuration + coolDownDuration
            + Double(sets) * perSet
            + Double(sets - 1) * setRecoveryDuration
    }

    /// Weighted average power for the planned session, in watts — a better
    /// guide to how hard it feels than plain average power, because hard
    /// efforts cost disproportionately more than easy riding.
    ///
    /// Standard method: a second-by-second power series, its 30-second
    /// rolling average, each value raised to the 4th power, the mean of
    /// those, then the 4th root. Computed from the target powers, so it's
    /// exact for what the trainer will hold (O(n) in session seconds).
    var weightedAveragePower: Int {
        var watts: [Double] = []
        watts.reserveCapacity(Int(totalDuration))
        for segment in segments {
            watts.append(contentsOf: repeatElement(Double(segment.power), count: max(Int(segment.duration.rounded()), 0)))
        }
        guard !watts.isEmpty else { return 0 }
        let window = 30
        guard watts.count >= window else {
            return Int((watts.reduce(0, +) / Double(watts.count)).rounded())
        }
        var rolling = watts[0..<window].reduce(0, +)
        var sumFourth = pow(rolling / Double(window), 4)
        for i in window..<watts.count {
            rolling += watts[i] - watts[i - window]
            sumFourth += pow(rolling / Double(window), 4)
        }
        let count = Double(watts.count - window + 1)
        return Int(pow(sumFourth / count, 0.25).rounded())
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

extension IntervalSession {
    private enum CodingKeys: String, CodingKey {
        case id, customName, intervalCount, workDuration, workPower, restDuration, restPower,
             warmUpDuration, coolDownDuration, setsEnabled, setCount, setRecoveryDuration
    }

    /// Custom decoding so sessions saved before sets existed (and workouts
    /// checkpointed with them) still load: missing set fields mean "no sets".
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        intervalCount = try c.decode(Int.self, forKey: .intervalCount)
        workDuration = try c.decode(TimeInterval.self, forKey: .workDuration)
        workPower = try c.decode(Int.self, forKey: .workPower)
        restDuration = try c.decode(TimeInterval.self, forKey: .restDuration)
        restPower = try c.decode(Int.self, forKey: .restPower)
        warmUpDuration = try c.decode(TimeInterval.self, forKey: .warmUpDuration)
        coolDownDuration = try c.decode(TimeInterval.self, forKey: .coolDownDuration)
        setsEnabled = try c.decodeIfPresent(Bool.self, forKey: .setsEnabled) ?? false
        setCount = try c.decodeIfPresent(Int.self, forKey: .setCount) ?? 3
        setRecoveryDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .setRecoveryDuration) ?? 180
    }
}

struct IntervalSegment: Equatable {
    /// `setRest` is the longer recovery between sets.
    enum Kind: String { case warmUp, work, rest, setRest, coolDown }
    let kind: Kind
    let start: TimeInterval
    let duration: TimeInterval
    let power: Int
    /// 1-based interval number within its set for work and rest segments; 0 otherwise.
    let number: Int
    /// 1-based set for work, rest and set-recovery segments (the set just
    /// finished, for `setRest`); 0 for warm-up and cool-down.
    let set: Int
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
