import Foundation

/// Works out, after a Zone 2 ride, whether a different starting power would
/// suit the rider better, so the Summary can offer to update it.
///
/// Zone Targeting starts from the rider's set power and nudges it to hold
/// heart rate at the Zone 2 target. It moves deliberately slowly (about 5 W
/// every 90 s upwards), so a set power 50 W too low takes a quarter of an hour
/// to correct.
///
/// The suggestion is the power that held heart rate on target in the *second
/// half* of the ride. Cardiac drift (heart rate creeping up at the same power)
/// means power always has to come down somewhat over a long ride; starting at
/// the later, lower power means Zone Targeting nudges up early and only eases
/// back towards the starting power later, rather than spending most of the
/// ride bringing power down, which riders find demoralising (George, Nov 2026:
/// the early-window version suggested 175 W on a ride that settled from 175
/// down to 165 W).
enum Zone2Anchor {
    /// Never earlier than this: warm-up, the controller's 3-minute grace and settling.
    static let earliestStart: TimeInterval = 8 * 60
    static let minRide: TimeInterval = 20 * 60
    /// Seconds with heart rate within this many bpm of target count as "on target".
    static let onTargetBand = 3.0
    static let minOnTargetSeconds = 5 * 60
    /// Smallest change worth suggesting.
    static let minDifference = 15

    struct Suggestion: Equatable {
        let current: Int
        let suggested: Int
        /// True when heart rate never reached the target in the window (the
        /// controller was still adjusting): the real anchor is further still,
        /// and this is where power had got to, a step towards it.
        let partial: Bool
    }

    static func suggestion(for workout: Workout, targetHR: Double, zoneTargeting: Bool) -> Suggestion? {
        guard zoneTargeting, !workout.isIntervalSession, workout.actualDuration >= minRide else { return nil }
        let current = workout.targetPower

        // 60-second rolling averages of heart rate and power.
        let samples = workout.samples
        guard samples.count >= Int(minRide) / 2 else { return nil }
        var hrWindow: [Double] = [], pWindow: [Double] = []
        var onTargetPower: [Double] = []
        var belowCount = 0, aboveCount = 0, inWindow = 0, windowPower: [Double] = []
        // The second half of the ride, up to two minutes before the end.
        let start = max(earliestStart, workout.actualDuration / 2)
        let end = workout.actualDuration - 2 * 60

        for s in samples {
            if let hr = s.heartRate, hr > 0 { hrWindow.append(Double(hr)) }
            if let p = s.power, p > 0 { pWindow.append(Double(p)) }
            if hrWindow.count > 60 { hrWindow.removeFirst() }
            if pWindow.count > 60 { pWindow.removeFirst() }
            guard s.timestamp >= start, s.timestamp <= end,
                  hrWindow.count >= 45, pWindow.count >= 45 else { continue }
            let hr = hrWindow.reduce(0, +) / Double(hrWindow.count)
            let p = pWindow.reduce(0, +) / Double(pWindow.count)
            inWindow += 1
            windowPower.append(p)
            if abs(hr - targetHR) <= onTargetBand { onTargetPower.append(p) }
            else if hr < targetHR { belowCount += 1 } else { aboveCount += 1 }
        }
        guard inWindow >= 5 * 60 else { return nil }

        let suggested: Int
        var partial = false
        if onTargetPower.count >= minOnTargetSeconds {
            suggested = roundTo5(median(onTargetPower))
        } else if Double(belowCount) >= 0.8 * Double(inWindow) || Double(aboveCount) >= 0.8 * Double(inWindow) {
            // Never settled: suggest where the controller had got to by the end
            // of the window (the last two minutes), a step in the right direction.
            suggested = max(50, roundTo5(median(Array(windowPower.suffix(120)))))
            partial = true
        } else {
            return nil
        }

        // Only worth asking about a real difference (Zone Targeting covers
        // smaller ones within a few minutes anyway).
        guard abs(suggested - current) >= minDifference else { return nil }
        return Suggestion(current: current, suggested: suggested, partial: partial)
    }

    // MARK: - Not asking twice

    private static let declinedKey = "zone2AnchorDeclined"   // "current:suggested"

    /// True if the rider already turned down a similar suggestion for this starting power.
    static func wasDeclined(_ s: Suggestion) -> Bool {
        guard let stored = UserDefaults.standard.string(forKey: declinedKey) else { return false }
        let parts = stored.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return false }
        return parts[0] == s.current && abs(parts[1] - s.suggested) < 10
    }

    static func recordDeclined(_ s: Suggestion) {
        UserDefaults.standard.set("\(s.current):\(s.suggested)", forKey: declinedKey)
    }

    /// Posted when the rider accepts a new starting power, so Setup updates.
    static let didChange = Notification.Name("Zone2AnchorDidChange")

    static func accept(_ s: Suggestion) {
        UserDefaults.standard.set(s.suggested, forKey: "targetPower")
        UserDefaults.standard.removeObject(forKey: declinedKey)
        NotificationCenter.default.post(name: didChange, object: nil, userInfo: ["power": s.suggested])
    }

    // MARK: - Helpers

    private static func median(_ xs: [Double]) -> Double {
        let s = xs.sorted()
        return s.isEmpty ? 0 : s[s.count / 2]
    }

    private static func roundTo5(_ x: Double) -> Int { Int((x / 5).rounded()) * 5 }
}
