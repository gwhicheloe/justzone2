import Foundation

/// Short on-screen coaching messages during interval sessions.
///
/// Deterministic: the code picks the moments and fills written lines from
/// `CoachPhrases` with the session's real numbers. (An on-device language
/// model was tried first, Oct–Nov 2026; it invented times and counts and
/// needed seconds per line, so it was dropped.) For each moment a line is
/// drawn from a shuffled pack, so nothing repeats until the pack is used up.
///
/// Moments: an introduction at the start, midway through a warm-up, 10 s
/// before every interval, halfway through intervals longer than two minutes,
/// 10 s before every interval ends, the start of the cool-down and a wrap-up.
/// The session's halfway point is folded into whichever moment lands there.
/// Logged as `[COACH]`.
@MainActor
final class IntervalCoach: ObservableObject {
    /// A message: a short label for the moment ("GET READY") and the line.
    struct Line: Equatable {
        let tag: String
        let text: String
    }

    /// The message on screen now, or nil.
    @Published private(set) var message: Line?

    /// Longest a message stays up (the next one replaces it sooner).
    static let displaySeconds: TimeInterval = 25
    /// A moment that's passed by more than this (e.g. resuming a recovered
    /// ride) is skipped, not shown late.
    static let maxLate: TimeInterval = 5

    /// UserDefaults key for the Coach toggle. Off by default; the rider turns
    /// it on from the workout screen and the choice is remembered.
    static let enabledKey = "coachEnabled"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    enum Kind: String { case intro, plan, warmUp, prepare, midEffort, ending, warmDown, wrapUp }

    /// The character of a session, from its interval length (internal only;
    /// it shapes the wording, the rider never sees the categories):
    /// a minute or less short and sharp, under 4 minutes hard, under 8
    /// minutes medium, 8 minutes or more long.
    enum SessionType { case shortSharp, hard, medium, long }

    private struct Cue {
        let at: TimeInterval
        let kind: Kind
        /// The interval it's about (1-based across sets): the one in progress
        /// for midEffort/ending, the one coming up for prepare.
        let interval: Int
        let segment: IntervalSegment
        var halfway = false
    }

    private let session: IntervalSession
    private let total: Int
    private let cues: [Cue]
    private var next = 0
    private var packs: [String: [String]] = [:]
    private var hideTask: Task<Void, Never>?

    init(session: IntervalSession) {
        self.session = session
        let work = session.segments.filter(\.isWork)
        self.total = work.count
        self.cues = Self.schedule(for: session)
        dlog("[COACH] \(cues.count) moments planned: " + cues.map { "\(Int($0.at))s \($0.kind.rawValue)\($0.halfway ? "+halfway" : "")" }.joined(separator: ", "))
    }

    // MARK: - Schedule

    private static func schedule(for session: IntervalSession) -> [Cue] {
        let segments = session.segments
        let work = segments.filter(\.isWork)
        guard let first = segments.first, !work.isEmpty else { return [] }
        var all: [Cue] = [Cue(at: 0, kind: .intro, interval: 0, segment: first)]

        // With a warm-up, the welcome (what the session is for) and the plan
        // (its shape) are two messages: one long one didn't fit the space.
        if first.kind == .warmUp, first.duration >= 60 {
            all.append(Cue(at: 20, kind: .plan, interval: 0, segment: first))
        }
        if first.kind == .warmUp, first.duration >= 120 {
            all.append(Cue(at: first.duration / 2, kind: .warmUp, interval: 0, segment: first))
        }

        for (i, seg) in work.enumerated() {
            let n = i + 1
            // 10 s before it starts (the first one only if there's a warm-up
            // to say it in; otherwise the introduction covers it).
            if seg.start >= 20 {
                let previousEnd = i > 0 ? work[i - 1].end : 0
                all.append(Cue(at: max(seg.start - 10, previousEnd + 1), kind: .prepare, interval: n, segment: seg))
            }
            // Halfway through intervals longer than two minutes.
            if seg.duration > 120 {
                all.append(Cue(at: seg.start + seg.duration / 2, kind: .midEffort, interval: n, segment: seg))
            }
            // 10 s before it ends.
            all.append(Cue(at: max(seg.start + 2, seg.end - 10), kind: .ending, interval: n, segment: seg))
        }

        if let cool = segments.first(where: { $0.kind == .coolDown }) {
            if cool.duration >= 90 {
                all.append(Cue(at: cool.start + 3, kind: .warmDown, interval: work.count, segment: cool))
                all.append(Cue(at: cool.end - 30, kind: .wrapUp, interval: work.count, segment: cool))
            } else {
                all.append(Cue(at: cool.start + 3, kind: .wrapUp, interval: work.count, segment: cool))
            }
        }
        all.sort { $0.at < $1.at }

        // The session's halfway point (half the work done) goes into the first
        // interval-related moment at or after it.
        let totalWork = work.reduce(0) { $0 + $1.duration }
        var acc: TimeInterval = 0
        var halfwayAt: TimeInterval?
        for seg in work {
            if acc + seg.duration >= totalWork / 2 { halfwayAt = seg.start + (totalWork / 2 - acc); break }
            acc += seg.duration
        }
        if work.count >= 3, let h = halfwayAt,
           let i = all.firstIndex(where: { $0.at >= h - 1 && [.prepare, .midEffort, .ending].contains($0.kind) }) {
            all[i].halfway = true
        }

        // Two moments on top of each other (very short intervals): keep the first.
        var kept: [Cue] = []
        for c in all {
            if let last = kept.last, c.at - last.at < 6 {
                if c.halfway { kept[kept.count - 1].halfway = true }
                continue
            }
            kept.append(c)
        }
        return kept
    }

    // MARK: - Running

    /// Call every timer tick during the ride.
    func tick(elapsed: TimeInterval, heartRate: Int) {
        while next < cues.count, elapsed >= cues[next].at {
            let cue = cues[next]
            next += 1
            if elapsed - cue.at > Self.maxLate {
                dlog("[COACH] skipped \(Int(cue.at))s \(cue.kind.rawValue) (passed)")
                continue
            }
            show(line(for: cue), for: cue)
        }
    }

    func stop() {
        hideTask?.cancel()
        message = nil
    }

    private func show(_ line: Line, for cue: Cue) {
        message = line
        dlog("[COACH] \(Int(cue.at))s \(cue.kind.rawValue) [\(line.tag)]: \(line.text)")
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.displaySeconds * 1_000_000_000))
            if !Task.isCancelled { self?.message = nil }
        }
    }

    // MARK: - Lines

    private func line(for cue: Cue) -> Line {
        let P = CoachPhrases.self
        func make(_ tagKey: String, _ key: String, _ options: [String]) -> Line {
            Line(tag: P.tags[tagKey] ?? "", text: fill(draw(key, options), cue))
        }
        let phase = phaseOf(cue.interval)
        let lastInSet = session.setsEnabled && cue.segment.number == session.intervalCount
        switch cue.kind {
        case .intro:
            return Line(tag: P.tags["intro"]!, text: introduction())
        case .plan:
            return Line(tag: P.tags["plan"]!, text: plan())
        case .warmUp:
            return make("warmUp", "warmUp", P.warmUp)
        case .prepare:
            if cue.interval == 1 { return make("prepare", "prepareFirst", P.prepareFirst) }
            if cue.interval == total { return make("prepareFinal", "prepareFinal", P.prepareFinal) }
            if session.setsEnabled && cue.segment.number == 1 {
                return cue.segment.set == session.setCount
                    ? make("prepareNewSet", "prepareLastSet", P.prepareLastSet)
                    : make("prepareNewSet", "prepareNewSet", P.prepareNewSet)
            }
            if cue.halfway { return make("halfway", "prepareHalfway", P.prepareHalfway) }
            let byType = P.prepareByType[sessionType] ?? []
            switch phase {
            case .early: return make("prepare", "prepareEarly", P.prepareEarly + byType)
            case .middle: return make("prepare", "prepareMiddle", P.prepareMiddle + byType)
            case .late: return make("prepare", "prepareLate", P.prepareLate + byType)
            }
        case .midEffort:
            if cue.halfway { return make("halfway", "midEffortHalfway", P.midEffortHalfway) }
            let tag: String
            switch sessionType {
            case .hard: tag = "HANG TOUGH"
            case .long: tag = "STEADY"
            default: tag = "HOLD THE PACE"
            }
            return Line(tag: tag, text: fill(draw("midEffort", P.midEffort[sessionType] ?? P.midEffort[.medium]!), cue))
        case .ending:
            if cue.interval == total { return make("endingFinal", "endingFinal", P.endingFinal) }
            if cue.halfway { return make("halfway", "endingHalfway", P.endingHalfway) }
            if lastInSet { return make("ending", "endingLastInSet", P.endingLastInSet) }
            let byType = P.endingByType[sessionType] ?? []
            switch phase {
            case .early: return make("ending", "endingEarly", P.endingEarly + byType)
            case .middle: return make("ending", "endingMiddle", P.endingMiddle + byType)
            case .late: return make("ending", "endingLate", P.endingLate + byType)
            }
        case .warmDown:
            return make("warmDown", "warmDown", P.warmDown)
        case .wrapUp:
            return session.setsEnabled
                ? make("wrapUp", "wrapUpSets", P.wrapUpSets + P.wrapUp)
                : make("wrapUp", "wrapUp", P.wrapUp)
        }
    }

    private enum Phase { case early, middle, late }

    /// First, middle or last third of the session's intervals.
    private func phaseOf(_ n: Int) -> Phase {
        let p = Double(n) / Double(max(total, 1))
        return p <= 1.0 / 3 ? .early : (p <= 2.0 / 3 ? .middle : .late)
    }

    /// Greeting + what the session is for. Without a warm-up there's no
    /// time for a separate plan message, so the plan comes straight after.
    private func introduction() -> String {
        let P = CoachPhrases.self
        let greeting: String = {
            switch Self.partOfDay() {
            case "morning": return "Good morning. "
            case "afternoon": return "Good afternoon. "
            case "evening": return "Good evening. "
            default: return ""
            }
        }()
        let hasWarmUp = (session.segments.first?.kind == .warmUp) && (session.segments.first?.duration ?? 0) >= 60
        if hasWarmUp {
            return fill(greeting + draw("kind", kindLines), nil)
        }
        let shape = draw("structure", session.setsEnabled ? P.structureSets : P.structure)
        return fill(greeting + shape + " " + draw("start", P.startNoWarmUp), nil)
    }

    /// The session's shape and how it starts.
    private func plan() -> String {
        let P = CoachPhrases.self
        let shape = draw("structure", session.setsEnabled ? P.structureSets : P.structure)
        return fill(shape + " " + draw("start", P.startWithWarmUp), nil)
    }

    /// Next line from a shuffled pack: nothing repeats until all have been used.
    private func draw(_ key: String, _ options: [String]) -> String {
        if packs[key]?.isEmpty ?? true { packs[key] = options.shuffled() }
        return packs[key]!.removeLast()
    }

    private func fill(_ template: String, _ cue: Cue?) -> String {
        var s = template
        let n = cue?.interval ?? 0
        let toGo = total - n + 1   // for "prepare": the next interval and those after it
        let values: [String: String] = [
            "{n}": "\(n)",
            "{next}": "\(n)",
            "{total}": "\(total)",
            "{count}": "\(session.intervalCount)",
            "{toGo}": "\(toGo) \(toGo == 1 ? "interval" : "intervals")",
            "{left}": "\(total - n) \(total - n == 1 ? "interval" : "intervals")",
            "{workTime}": Self.durationNoun(Double(total) * session.workDuration),
            "{set}": "\(cue?.segment.set ?? 1)",
            "{sets}": "\(session.setCount)",
            "{workNoun}": Self.durationNoun(session.workDuration),
            "{rest}": Self.durationNoun(session.restDuration),
            "{warmUp}": Self.durationNoun(session.segments.first?.duration ?? 0),
        ]
        for (k, v) in values { s = s.replacingOccurrences(of: k, with: v) }
        // "{total} intervals done" at the start of a sentence reads fine as a
        // numeral; capitalise the first letter in case a template starts lower.
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    // MARK: - Words

    /// What kind of session this is, judged from its shape.
    private var sessionType: SessionType {
        switch session.workDuration {
        case ...60: return .shortSharp
        case ..<240: return .hard
        case ..<480: return .medium
        default: return .long
        }
    }

    /// Introduction lines for this session (on/off sessions get their own too).
    private var kindLines: [String] {
        let lines = CoachPhrases.kind[sessionType] ?? CoachPhrases.kind[.medium]!
        let onOff = session.workDuration <= 60 && session.restDuration <= session.workDuration
        return onOff ? lines + CoachPhrases.kindOnOff : lines
    }

    /// "30 seconds", "1 minute", "4 minutes".
    /// "30 seconds", "1 minute", "90 seconds", "4 minutes".
    static func durationNoun(_ t: TimeInterval) -> String {
        let secs = Int(t.rounded())
        if secs < 60 || (secs < 180 && secs % 60 != 0) { return "\(secs) seconds" }
        let m = Int((t / 60).rounded())
        return m == 1 ? "1 minute" : "\(m) minutes"
    }

    /// Morning, afternoon, evening or night, from the phone's clock.
    static func partOfDay(_ date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
}
