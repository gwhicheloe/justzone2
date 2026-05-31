import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchAppInstalled = false
    /// HR received from Watch over WCSession (now the only HR transport).
    @Published var fallbackHeartRate: Int = 0
    /// True once the Watch has delivered at least one HR sample for the current
    /// workout. Used by UI to signal "Watch is recording" without needing a
    /// separate session-state ack.
    @Published var hasReceivedHR = false
    /// Non-nil when the Watch reported a session-start error the user needs to
    /// resolve (e.g. Watch app was backgrounded). Set back to nil to dismiss.
    @Published var watchStartError: String?

    private var session: WCSession?

    // HR delivery stats — used to surface drops in shipping diagnostics.
    private var hrRecvCount = 0
    private var hrLastSeq = 0
    private var hrGaps = 0
    /// Stamped when the iPhone (re)launches the Watch workout, so we can log how
    /// long the Watch took to deliver its first HR sample.
    private var watchLaunchTime: Date?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        dlog("[IPHONE-WC] init — activate() called")
    }

    // MARK: - Send Helpers (route every send through one logged path)

    /// Send a real-time message; logs reachability and any error.
    private func send(_ payload: [String: Any], op: String) {
        guard let session = session else {
            dlog("[IPHONE-WC] \(op) DROPPED — no session")
            return
        }
        dlog("[IPHONE-WC] \(op) — \(wcSnapshot(session))")
        guard session.isReachable else {
            dlog("[IPHONE-WC] \(op) DROPPED — not reachable")
            return
        }
        session.sendMessage(payload, replyHandler: nil) { error in
            dlog("[IPHONE-WC] \(op) sendMessage FAILED: \(error.localizedDescription)")
        }
        dsignpost("iPhone→Watch \(op)")
    }

    /// Queue a guaranteed-delivery message; logs reachability snapshot.
    private func queue(_ payload: [String: Any], op: String) {
        guard let session = session else {
            dlog("[IPHONE-WC] \(op) (userInfo) DROPPED — no session")
            return
        }
        var p = payload
        p["timestamp"] = Date().timeIntervalSince1970
        session.transferUserInfo(p)
        dlog("[IPHONE-WC] \(op) (userInfo) queued — \(wcSnapshot(session))")
        dsignpost("iPhone→Watch \(op) userInfo")
    }

    // MARK: - Workout Lifecycle Commands (iPhone → Watch)

    func sendStartWorkout() {
        send(["type": "startWorkout"], op: "sendStartWorkout")
        queue(["type": "startWorkout"], op: "sendStartWorkout")
    }

    /// Mode B: tells Watch to start a display-only session (no HR, no saved workout)
    /// so the Watch app stays alive in the background for update delivery.
    func sendStartDisplayWorkout() {
        send(["type": "startDisplayWorkout"], op: "sendStartDisplayWorkout")
    }

    func sendStopWorkout() {
        send(["type": "stopWorkout"], op: "sendStopWorkout")
        queue(["type": "stopWorkout"], op: "sendStopWorkout")
    }

    func sendPauseWorkout() {
        send(["type": "pauseWorkout"], op: "sendPauseWorkout")
    }

    func sendResumeWorkout() {
        send(["type": "resumeWorkout"], op: "sendResumeWorkout")
    }

    // MARK: - Display Updates (iPhone → Watch, ~1 Hz)

    func sendWorkoutUpdate(
        heartRate: Int,
        power: Int,
        elapsedTime: TimeInterval,
        chunkRemaining: TimeInterval,
        currentChunk: Int,
        totalChunks: Int,
        state: String
    ) {
        guard let session = session, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "workoutUpdate",
            "heartRate": heartRate,
            "power": power,
            "elapsedTime": elapsedTime,
            "chunkRemaining": chunkRemaining,
            "currentChunk": currentChunk,
            "totalChunks": totalChunks,
            "state": state
        ]
        // No log per tick (1 Hz spam); errors are logged.
        session.sendMessage(message, replyHandler: nil) { error in
            dlog("[IPHONE-WC] sendWorkoutUpdate FAILED: \(error.localizedDescription)")
        }
    }

    func sendWorkoutEnded() {
        send(["type": "workoutEnded"], op: "sendWorkoutEnded")
        queue(["type": "workoutEnded"], op: "sendWorkoutEnded")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        dlog("[IPHONE-WC] activation completed — state=\(activationState.rawValue) error=\(error?.localizedDescription ?? "none") \(wcSnapshot(session))")
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        dlog("[IPHONE-WC] sessionDidBecomeInactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        dlog("[IPHONE-WC] sessionDidDeactivate — reactivating")
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        dlog("[IPHONE-WC] reachability changed — \(wcSnapshot(session))")
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        dlog("[IPHONE-WC] watchState changed — \(wcSnapshot(session))")
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    /// Receives real-time messages from Watch (HR samples + control errors).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        if type == "heartRateUpdate", let hr = message["heartRate"] as? Int {
            let seq = message["seq"] as? Int ?? 0
            dsignpost("Watch→iPhone HR=\(hr) seq=\(seq)")
            Task { @MainActor in
                self.fallbackHeartRate = hr
                if !self.hasReceivedHR { self.hasReceivedHR = true }
                self.recordHRDelivery(seq: seq)
            }
        } else if type == "watchError", let kind = message["kind"] as? String {
            handleWatchError(kind: kind)
        } else {
            dlog("[IPHONE-WC] received message type=\(type)")
        }
    }

    /// Called by WorkoutViewModel each time it (re)launches the Watch workout.
    func markWatchLaunch() {
        watchLaunchTime = Date()
    }

    /// Track HR samples received — log first arrival, gaps, and a 30-sample rollup.
    private func recordHRDelivery(seq: Int) {
        hrRecvCount += 1
        if hrRecvCount == 1 {
            if let launch = watchLaunchTime {
                let secs = Date().timeIntervalSince(launch)
                dlog(String(format: "[IPHONE-WC] HR first received seq=%d — Watch HR online in %.1fs", seq, secs))
            } else {
                dlog("[IPHONE-WC] HR first received seq=\(seq)")
            }
        }
        // Detect a gap: seq jumped by >1 since last
        if seq > 0 && hrLastSeq > 0 && seq > hrLastSeq + 1 {
            let dropped = seq - hrLastSeq - 1
            hrGaps += dropped
            dlog("[IPHONE-WC] HR gap detected — last=\(hrLastSeq) now=\(seq) dropped=\(dropped)")
        }
        if seq > 0 { hrLastSeq = seq }
        if hrRecvCount % 30 == 0 {
            dlog("[IPHONE-WC] HR rollup — received=\(hrRecvCount) latestSeq=\(hrLastSeq) totalGaps=\(hrGaps)")
        }
    }

    /// Reset HR counters at the start of a workout.
    func resetHRStats() {
        hrRecvCount = 0
        hrLastSeq = 0
        hrGaps = 0
        hasReceivedHR = false
        watchLaunchTime = nil
    }

    /// Receives guaranteed-delivery messages from Watch (e.g. Watch-side diagnostic logs).
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let type = userInfo["type"] as? String else { return }
        if type == "watchLog", let log = userInfo["log"] as? String {
            let lineCount = log.components(separatedBy: "\n").filter { !$0.isEmpty }.count
            dlog("[IPHONE-WC] Watch log received (\(lineCount) lines)")
            DiagnosticsLogger.shared.appendWatchLog(log)
        } else if type == "watchError", let kind = userInfo["kind"] as? String {
            handleWatchError(kind: kind)
        } else {
            dlog("[IPHONE-WC] received userInfo type=\(type)")
        }
    }

    nonisolated private func handleWatchError(kind: String) {
        dlog("[IPHONE-WC] Watch error received — kind=\(kind)")
        let message: String
        switch kind {
        case "backgroundStart":
            message = "Your Apple Watch was asleep. Raise your wrist or tap the Watch screen to wake it, then tap the heart icon to retry."
        default:
            message = "Apple Watch couldn't start the workout."
        }
        Task { @MainActor in
            self.watchStartError = message
        }
    }
}
