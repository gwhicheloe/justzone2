import Foundation
import FoundationModels

/// EXPERIMENT (branch experiment/interval-encouragement): short on-screen
/// coaching messages during interval sessions, phrased by Apple's on-device
/// language model (Foundation Models, Apple Intelligence devices only).
///
/// Built for a small model: the code does the thinking and gives it one
/// narrow job at a time.
/// - **Moments.** The session is turned into a schedule of moments
///   (introduction, warm-up, end of warm-up, during an interval, between
///   intervals, warm-down, wrap-up), each with its own short role.
/// - **Facts.** Each prompt carries only true facts, in words: where the rider
///   is, how many intervals are left, elapsed/remaining time, halfway, final
///   interval, new set.
/// - **Themes.** The code picks what each message is about from a rotating
///   list per moment (breathing, form, a drink…), so messages vary by design.
/// - **History.** Each prompt lists the recent messages, so it doesn't repeat.
/// - **Checks.** Numbers must come from the facts; no outdoor riding talk;
///   "halfway" only at halfway; one retry, then a fixed line.
/// Lines are generated one at a time, ~30 s ahead. Logged as `[COACH]`.
@MainActor
final class IntervalCoach: ObservableObject {
    /// The message on screen now, or nil.
    @Published private(set) var message: String?

    static let displaySeconds: TimeInterval = 25
    /// UserDefaults key for the Coach toggle (default on).
    static let enabledKey = "coachEnabled"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    /// Ordinary moments closer together than this are dropped (key ones are kept).
    static let minGap: TimeInterval = 40
    static let lead: TimeInterval = 30
    static let maxLate: TimeInterval = 12

    enum Kind: String {
        case intro, warmUp, warmUpEnd, during, between, warmDown, wrapUp
    }

    private struct Cue {
        let at: TimeInterval
        let kind: Kind
        /// The interval it's about (1-based across sets): the one in progress
        /// for `during`, the one just finished for `between`.
        let interval: Int
        let segment: IntervalSegment
        var key: Bool
        var midEffort = false        // `during`, middle of a long interval
        var halfway = false
    }

    private let session: IntervalSession
    private let work: [IntervalSegment]
    private let cues: [Cue]
    private var next = 0
    private var lines: [Int: String] = [:]
    private var generating: Int?
    private var recent: [String] = []
    private var themeCounters: [String: Int] = [:]
    private var startHR: Int?
    private var hideTask: Task<Void, Never>?
    private let modelAvailable: Bool

    init(session: IntervalSession) {
        self.session = session
        self.work = session.segments.filter(\.isWork)
        self.cues = Self.schedule(for: session)

        switch SystemLanguageModel.default.availability {
        case .available:
            modelAvailable = true
            dlog("[COACH] on-device model available; \(cues.count) cues planned")
        case .unavailable(let reason):
            modelAvailable = false
            dlog("[COACH] on-device model unavailable (\(reason)); using fixed lines; \(cues.count) cues planned")
        }
        for c in cues {
            dlog("[COACH] cue t=\(Int(c.at))s \(c.kind.rawValue) #\(c.interval)\(c.midEffort ? " mid" : "")\(c.halfway ? " HALFWAY" : "")\(c.key ? " (key)" : "")")
        }
    }

    // MARK: - Schedule

    private static func schedule(for session: IntervalSession) -> [Cue] {
        let segments = session.segments
        let work = segments.filter(\.isWork)
        guard let first = segments.first, !work.isEmpty else { return [] }
        var all: [Cue] = [Cue(at: 0, kind: .intro, interval: 0, segment: first, key: true)]

        if first.kind == .warmUp {
            if first.duration >= 120 {
                all.append(Cue(at: first.duration / 2, kind: .warmUp, interval: 0, segment: first, key: true))
            }
            if first.duration >= 30 {
                all.append(Cue(at: max(first.end - 15, 20), kind: .warmUpEnd, interval: 1, segment: work[0], key: true))
            }
        }

        for (i, seg) in work.enumerated() {
            let n = i + 1
            let isLast = n == work.count
            if seg.duration >= 180 {
                var c = Cue(at: seg.start + seg.duration / 2, kind: .during, interval: n, segment: seg, key: false)
                c.midEffort = true
                all.append(c)
            }
            if seg.duration >= 30 {
                all.append(Cue(at: seg.end - min(15, seg.duration * 0.4), kind: .during, interval: n, segment: seg, key: isLast))
            }
            if !isLast {
                let nextWork = work[i + 1]
                let newSet = session.setsEnabled && nextWork.number == 1
                let at = max(nextWork.start - 15, seg.end + 3)
                all.append(Cue(at: at, kind: .between, interval: n, segment: nextWork, key: n + 1 == work.count || newSet))
            }
        }

        if let cool = segments.first(where: { $0.kind == .coolDown }) {
            if cool.duration >= 90 {
                all.append(Cue(at: cool.start + 3, kind: .warmDown, interval: work.count, segment: cool, key: true))
                all.append(Cue(at: cool.end - 30, kind: .wrapUp, interval: work.count, segment: cool, key: true))
            } else {
                all.append(Cue(at: cool.start + 3, kind: .wrapUp, interval: work.count, segment: cool, key: true))
            }
        }
        all.sort { $0.at < $1.at }

        // Halfway: the first moment at or after half the session's work is done.
        let totalWork = work.reduce(0) { $0 + $1.duration }
        var acc: TimeInterval = 0
        var halfwayAt: TimeInterval?
        for seg in work {
            if acc + seg.duration >= totalWork / 2 { halfwayAt = seg.start + (totalWork / 2 - acc); break }
            acc += seg.duration
        }
        if work.count >= 3, let h = halfwayAt,
           let i = all.firstIndex(where: { $0.at >= h - 1 && ($0.kind == .during || $0.kind == .between) }) {
            all[i].halfway = true
            all[i].key = true
        }

        // Keep key moments; drop ordinary ones that crowd their neighbours.
        // Short on/off sessions (30/15s) cycle every ~45 s: one message per
        // cycle would be constant chatter, so they get a longer gap.
        let cycle = session.workDuration + session.restDuration
        let gap = cycle < 90 ? 80 : minGap
        var kept: [Cue] = []
        for (i, c) in all.enumerated() {
            let gapBefore = c.at - (kept.last?.at ?? -.infinity)
            let nextKey = all[(i + 1)...].first(where: \.key)
            if c.key {
                if let last = kept.last, !last.key, gapBefore < gap { kept.removeLast() }
                if let last = kept.last, c.at - last.at < 8 {
                    if c.halfway { kept.removeLast() } else { continue }
                }
                kept.append(c)
            } else if gapBefore >= gap && (nextKey?.at ?? .infinity) - c.at >= gap / 2 {
                // Prefer variety: if this is the same kind as the last message
                // and a different kind comes along within half a minute, wait for it.
                if let last = kept.last, last.kind == c.kind,
                   all[(i + 1)...].prefix(while: { $0.at - c.at <= 30 })
                       .contains(where: { !$0.key && $0.kind != c.kind }) {
                    continue
                }
                kept.append(c)
            }
        }
        return kept
    }

    // MARK: - Running

    /// Call every timer tick during the ride.
    func tick(elapsed: TimeInterval, heartRate: Int) {
        if startHR == nil, heartRate > 0 { startHR = heartRate }

        while next < cues.count, elapsed - cues[next].at > Self.maxLate, lines[next] == nil, generating != next {
            dlog("[COACH] skipped t=\(Int(cues[next].at))s \(cues[next].kind.rawValue) (too late)")
            next += 1
        }
        guard next < cues.count else { return }

        if elapsed >= cues[next].at, let line = lines[next] {
            show(line, for: cues[next])
            lines[next] = nil
            next += 1
        }

        guard generating == nil else { return }
        if let i = (next..<cues.count).first(where: { lines[$0] == nil }), cues[i].at - elapsed <= Self.lead {
            generate(i, heartRate: heartRate)
        }
    }

    func stop() {
        hideTask?.cancel()
        message = nil
    }

    private func show(_ line: String, for cue: Cue) {
        message = line
        dlog("[COACH] showing t=\(Int(cue.at))s \(cue.kind.rawValue): \(line)")
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.displaySeconds * 1_000_000_000))
            if !Task.isCancelled { self?.message = nil }
        }
    }

    // MARK: - Generation

    private func generate(_ i: Int, heartRate: Int) {
        let cue = cues[i]
        guard modelAvailable else {
            accept(fallback(for: cue), for: i)
            return
        }
        generating = i
        let theme = nextTheme(for: cue)
        let instructions = Self.core + " " + role(for: cue)
        let (prompt, facts) = prompt(for: cue, theme: theme, heartRate: heartRate)
        Task {
            let started = Date()
            var line: String?
            do {
                for attempt in 1...2 where line == nil {
                    let lm = LanguageModelSession(instructions: instructions)
                    let response = try await lm.respond(to: prompt, options: GenerationOptions(temperature: 0.8))
                    line = clean(response.content, for: cue, facts: facts)
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    dlog("[COACH] \(cue.kind.rawValue) #\(cue.interval) t=\(Int(cue.at))s [\(theme ?? "-")] try \(attempt) in \(ms) ms: \(line ?? "(rejected: \(response.content.prefix(160)))")")
                }
            } catch {
                dlog("[COACH] generation failed for t=\(Int(cue.at))s: \(error)")
            }
            generating = nil
            accept(line ?? fallback(for: cue), for: i)
        }
    }

    private func accept(_ line: String, for i: Int) {
        lines[i] = line
        recent.append(line)
        if recent.count > 5 { recent.removeFirst(recent.count - 5) }
    }

    // MARK: - Instructions (shared core + a role per moment)

    private static let core = """
    You are a warm, calm cycling coach with a dry wit, beside a rider on an \
    indoor smart trainer. The trainer sets the power, so there are no roads, \
    hills, gears or weather. Plain, natural British English: no flowery \
    metaphors or similes. Never use digits, emojis, quotation marks or \
    hashtags. Only use numbers that appear in the facts you're given, and \
    mention times only when they genuinely help; most messages shouldn't. \
    Vary how you begin: never start with Right, Alright or Right now, and \
    don't call the rider champ or champion. Sound like a real coach, not a \
    poster, and never say what you've said before.
    """

    private func role(for cue: Cue) -> String {
        switch cue.kind {
        case .intro:
            return "Your job now: welcome the rider and introduce today's session: what kind of session it is, what it does for them, and how to approach it. Up to two short sentences, at most 30 words."
        case .warmUp:
            return "Your job now: help the rider settle into the warm-up. It's easy riding with no pressure; the hard work comes later. One or two short sentences, at most 20 words."
        case .warmUpEnd:
            return "Your job now: the warm-up is ending and the first hard interval starts in a few seconds. Get the rider ready for it. At most 18 words."
        case .during:
            return cue.midEffort
                ? "Your job now: the rider is in the middle of a long, hard effort. Help them stay calm and settled through it. At most 18 words."
                : "Your job now: the rider is in the closing seconds of a hard effort. Help them hold on to the end. Short and punchy: at most 14 words."
        case .between:
            return "Your job now: the rider is recovering between hard intervals, and the next one starts in a few seconds. Help them recover and get ready. One or two short sentences, at most 20 words."
        case .warmDown:
            return "Your job now: all the hard intervals are done and the easy cool-down has begun. Help the rider unwind. One or two short sentences, at most 20 words."
        case .wrapUp:
            return "Your job now: the session is about to end. Sum up what the rider has done and congratulate them warmly. Up to two short sentences, at most 30 words."
        }
    }

    // MARK: - Themes (the code picks what each message is about)

    private static let themes: [String: [String]] = [
        "warmUp": ["loosening up and finding a smooth pedal stroke",
                   "relaxed breathing and a calm mind before the work",
                   "what today's session will build",
                   "getting comfortable: grip, shoulders and posture"],
        "during": ["holding good form as it gets tough",
                   "keeping the face, jaw and shoulders relaxed under effort",
                   "steady, rhythmic breathing",
                   "the end of this effort is close",
                   "a smooth, round pedal stroke",
                   "pride in doing the hard part"],
        "duringMid": ["settling into the effort and pacing it evenly",
                      "staying calm and patient",
                      "breaking the effort into small chunks"],
        "between": ["breathing deeply and letting the heart rate settle",
                    "relaxing the grip and dropping the shoulders",
                    "taking a drink",
                    "a quick mental reset before the next one",
                    "what these efforts are building",
                    "spinning the legs easily to clear them"],
        "warmDown": ["spinning easy and letting the body settle",
                     "the satisfaction of a job well done",
                     "breathing slowing down and heart rate easing"],
    ]

    private func nextTheme(for cue: Cue) -> String? {
        let key: String
        switch cue.kind {
        case .warmUp: key = "warmUp"
        case .during: key = cue.midEffort ? "duringMid" : "during"
        case .between: key = "between"
        case .warmDown: key = "warmDown"
        default: return nil
        }
        guard let list = Self.themes[key] else { return nil }
        let i = themeCounters[key, default: 0]
        themeCounters[key] = i + 1
        return list[i % list.count]
    }

    // MARK: - Prompt (facts in words, theme, history)

    /// The prompt, and the facts alone (what numbers are checked against —
    /// not the history, or a number from an earlier message could slip through).
    private func prompt(for cue: Cue, theme: String?, heartRate: Int) -> (String, String) {
        let total = work.count
        let length = session.totalDuration
        var facts: [String] = []

        switch cue.kind {
        case .intro:
            facts.append("Today's session is \(sessionKind).")
            facts.append("Structure: \(structureInWords).")
            if let warm = session.segments.first, warm.kind == .warmUp {
                facts.append("It starts with an easy warm-up of \(timeInWords(warm.duration)).")
            } else {
                facts.append("There's no warm-up: the first interval starts straight away.")
            }
            facts.append("The whole session lasts \(timeInWords(length)).")
        case .warmUp:
            facts.append("They're \(timeInWords(cue.at)) into a warm-up of \(timeInWords(cue.segment.duration)).")
            facts.append("Still to come: \(structureInWords).")
        case .warmUpEnd:
            facts.append("The first of \(words(total)) intervals, each \(durationInWords(session.workDuration)), starts in a few seconds.")
        case .during:
            let n = cue.interval
            facts.append(n == total ? "This is the final interval of the session." : "This is interval \(words(n)) of \(words(total)), \(phase(n, of: total)).")
            if n < total { facts.append("\(capitalisedWords(total - n)) \(total - n == 1 ? "interval follows" : "intervals follow") this one.") }
            facts.append(cue.midEffort ? "They're about halfway through this one effort, with \(timeInWords(cue.segment.end - cue.at)) of it left." : "This effort ends in a few seconds.")
        case .between:
            let n = cue.interval
            facts.append("They've just finished interval \(words(n)) of \(words(total)).")
            if n + 1 == total {
                facts.append("The next one, starting in a few seconds, is the final interval.")
            } else if session.setsEnabled && cue.segment.number == 1 {
                facts.append("After this longer recovery, set \(words(cue.segment.set)) of \(words(session.setCount)) starts in a few seconds.")
            } else {
                facts.append("Interval \(words(n + 1)) starts in a few seconds; the session is \(phase(n + 1, of: total)).")
            }
        case .warmDown:
            facts.append("All \(words(total)) intervals are done. The cool-down lasts \(timeInWords(cue.segment.duration)).")
        case .wrapUp:
            facts.append("They completed all \(words(total)) intervals of \(durationInWords(session.workDuration))\(session.setsEnabled ? ", in \(words(session.setCount)) sets" : "").")
            facts.append("The session was \(sessionKind).")
            facts.append("It lasted \(timeInWords(length)) in all.")
        }

        if cue.halfway {
            facts.append("This moment marks halfway through the session's hard work: mention it.")
        }
        if cue.kind == .during || cue.kind == .between, let start = startHR, heartRate > 0 {
            if heartRate - start > 35 { facts.append("Their heart rate is well up: they're working hard.") }
            else if heartRate - start < 15 { facts.append("Their heart rate is still fairly low.") }
        }
        // Session time only between intervals, where it can help; during an
        // effort it got confused with the time left in the effort.
        if cue.kind == .between {
            facts.append("The whole session has \(timeInWords(length - cue.at)) left.")
        }

        let factText = facts.joined(separator: " ")
        var parts = ["Facts: " + factText]
        if let theme { parts.append("Focus of this message: \(theme).") }
        if !recent.isEmpty {
            parts.append("Messages you've already given (say something different): " + recent.map { "[\($0)]" }.joined(separator: " "))
        }
        parts.append("Write the message.")
        return (parts.joined(separator: "\n"), factText)
    }

    // MARK: - Checks

    private static let banned = ["mile", "kilomet", " km", "mph", "o'clock", "road", "hill", "climb",
                                 "cobble", "weather", "wind", "gust", "rain", "gear", "peloton",
                                 "descent", "corner", "finish line",
                                 // It doesn't know the time of day ("Morning." at 13:43).
                                 "morning", "afternoon", "evening", "tonight", "today's weather"]
    /// Number words that must come from the facts ("one" and "half" aren't
    /// checked: "last one", "second half" are fine).
    private static let numberWords: Set<String> = [
        "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
        "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
        "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "dozen"]

    /// Words, keeping hyphenated numbers whole ("twenty-two").
    private static func tokens(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "-" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
    }

    private func maxWords(for cue: Cue) -> Int {
        switch cue.kind {
        case .intro, .wrapUp: return 38
        case .during: return cue.midEffort ? 24 : 18
        default: return 26
        }
    }

    private func clean(_ raw: String, for cue: Cue, facts: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’[]"))
        s = s.split(whereSeparator: \.isNewline).joined(separator: " ")
        let count = s.split(separator: " ").count
        guard count >= 2, count <= maxWords(for: cue) else { return nil }
        let lower = s.lowercased()
        // No digits, except in "VO2max" (a real term, and in the facts).
        let withoutVO2 = lower.replacingOccurrences(of: "vo2", with: "").replacingOccurrences(of: "vo₂", with: "")
        guard withoutVO2.rangeOfCharacter(from: .decimalDigits) == nil,
              !withoutVO2.contains(where: { ("₀"..."₉").contains($0) }) else { return nil }
        // Openers it overused, and nicknames.
        if lower.hasPrefix("right") || lower.hasPrefix("alright") || lower.hasPrefix("all right") { return nil }
        if Self.tokens(lower).contains(where: { $0 == "champ" || $0 == "champion" }) { return nil }
        let opening = Self.tokens(lower).prefix(2)
        if recent.contains(where: { Self.tokens($0).prefix(2) == opening }) { return nil }
        guard !Self.banned.contains(where: { lower.contains($0) }) else { return nil }
        if !cue.halfway, ["halfway", "half way", "half-way"].contains(where: { lower.contains($0) }) {
            // Only allowed when the facts say "halfway through this one effort".
            if !(cue.midEffort && lower.contains("this")) { return nil }
        }
        // Every number word must appear, whole, in this moment's facts.
        let given = Set(Self.tokens(facts))
        let isNumber: (String) -> Bool = { t in t.split(separator: "-").contains { Self.numberWords.contains(String($0)) } }
        if Self.tokens(s).contains(where: { isNumber($0) && !given.contains($0) }) { return nil }
        let key = lower.filter(\.isLetter)
        guard !recent.contains(where: { $0.lowercased().filter(\.isLetter) == key }) else { return nil }
        return s
    }

    // MARK: - Words

    /// What kind of session this is, judged from its shape.
    private var sessionKind: String {
        let w = session.workDuration, r = session.restDuration
        switch w {
        case ..<21: return "a set of very short, sprint-style bursts that build top-end power"
        case ..<46 where r <= w: return "short on/off micro-intervals, like the thirty-fifteens from Rønnestad's research, which keep the heart and lungs near their maximum for a long time with little strain on the legs"
        case ..<121: return "short, punchy intervals that build the ability to go hard and recover quickly"
        case ..<481: return "VO2max intervals: hard efforts of a few minutes that push the heart and lungs towards their maximum to raise the aerobic ceiling"
        case ..<1201: return "threshold intervals: long, steady, hard efforts that raise the power you can hold for an hour"
        default: return "long tempo efforts that build endurance at a sustained, solid pace"
        }
    }

    private var structureInWords: String {
        var s = "\(words(session.intervalCount)) intervals of \(durationInWords(session.workDuration)), with \(durationInWords(session.restDuration)) easy between them"
        if session.setsEnabled {
            s += ", repeated in \(words(session.setCount)) sets with a longer recovery between sets"
        }
        return s
    }

    private func phase(_ n: Int, of total: Int) -> String {
        let p = Double(n) / Double(max(total, 1))
        switch p {
        case ..<0.3: return "early in the session, legs still fresh"
        case ..<0.55: return "building into the session"
        case ..<0.8: return "into the second half, fatigue starting to bite"
        default: return "near the end, only a few left"
        }
    }

    /// "under a minute", "about a minute", "about seventeen minutes".
    private func timeInWords(_ t: TimeInterval) -> String {
        if t < 45 { return "under a minute" }
        if t < 90 { return "about a minute" }
        return "about \(words(Int((t / 60).rounded()))) minutes"
    }

    private func durationInWords(_ t: TimeInterval) -> String {
        if t < 90 { return "\(words(Int(t))) seconds" }
        let m = Int((t / 60).rounded())
        return m == 1 ? "one minute" : "\(words(m)) minutes"
    }

    private func words(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "en_GB")
        return f.string(from: NSNumber(value: n)) ?? "several"
    }

    private func capitalisedWords(_ n: Int) -> String {
        let w = words(n)
        return w.prefix(1).uppercased() + w.dropFirst()
    }

    // MARK: - Fallback lines

    private var fallbackCount: [Kind: Int] = [:]

    private func fallback(for cue: Cue) -> String {
        // `during`: this interval is the last; `between`: the next one is.
        let final = cue.kind == .between ? cue.interval + 1 == work.count : cue.interval == work.count
        let options: [String]
        switch cue.kind {
        case .intro:     options = ["Welcome in. Ease into it, and let's make today count."]
        case .warmUp:    options = ["Nice and easy for now. Let the legs wake up.",
                                    "Settle in, breathe easy. The work comes later."]
        case .warmUpEnd: options = ["Warm-up's done. First effort coming up: relax and roll into it."]
        case .during:
            if cue.halfway { options = ["Halfway through the hard work. Everything from here is downhill."] }
            else if final { options = ["Final seconds of the final effort. Bring it home."] }
            else if cue.midEffort { options = ["Settle in. Smooth and patient through the middle."] }
            else { options = ["Nearly there. Hold your form to the end.",
                              "Seconds to go. Recovery's waiting.",
                              "Almost done with this one. Keep it smooth."] }
        case .between:
            if cue.halfway { options = ["Halfway through the hard work. Breathe, reset, keep going."] }
            else if final { options = ["Last one coming up. Make it your smoothest yet."] }
            else { options = ["Breathe deep and let it settle. Next one's coming.",
                              "Drop the shoulders, have a sip. Here comes the next.",
                              "Good work. Reset, then roll into the next one."] }
        case .warmDown:  options = ["That's the hard work done. Spin easy and enjoy it."]
        case .wrapUp:    options = ["Session complete. Every interval done. Brilliant work today."]
        }
        let i = fallbackCount[cue.kind, default: 0]
        fallbackCount[cue.kind] = i + 1
        return options[i % options.count]
    }
}
