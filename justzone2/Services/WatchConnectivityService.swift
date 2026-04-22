import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchAppInstalled = false
    /// HR received from Watch via WCSession fallback (when mirroring fails).
    @Published var fallbackHeartRate: Int = 0
    /// Non-nil when the Watch reported a session-start error the user needs to
    /// resolve (e.g. Watch app was backgrounded). Set back to nil to dismiss.
    @Published var watchStartError: String?

    private var session: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Mode A: Backup Commands (WCSession fallback for mirrored session)

    func sendStartWorkout() {
        guard let session = session else { return }
        // Use sendMessage for immediate delivery when reachable
        if session.isReachable {
            session.sendMessage(["type": "startWorkout"], replyHandler: nil) { error in
                print("Watch sendMessage failed: \(error.localizedDescription)")
            }
        }
        // Always queue via transferUserInfo as guaranteed-delivery fallback
        // This persists and delivers even when Watch screen is off
        session.transferUserInfo(["type": "startWorkout", "timestamp": Date().timeIntervalSince1970])
    }

    /// Mode B: tells Watch to start a display-only session (no HR, no saved workout)
    /// so the Watch app stays alive in the background for update delivery.
    func sendStartDisplayWorkout() {
        guard let session = session else { return }
        if session.isReachable {
            session.sendMessage(["type": "startDisplayWorkout"], replyHandler: nil) { error in
                print("Watch sendMessage failed: \(error.localizedDescription)")
            }
        }
    }

    func sendStopWorkout() {
        guard let session = session else { return }
        if session.isReachable {
            session.sendMessage(["type": "stopWorkout"], replyHandler: nil) { error in
                print("Watch sendMessage failed: \(error.localizedDescription)")
            }
        }
        session.transferUserInfo(["type": "stopWorkout", "timestamp": Date().timeIntervalSince1970])
    }

    func sendPauseWorkout() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["type": "pauseWorkout"], replyHandler: nil) { error in
            print("Watch send failed: \(error.localizedDescription)")
        }
    }

    func sendResumeWorkout() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["type": "resumeWorkout"], replyHandler: nil) { error in
            print("Watch send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Mode B: Display-Only Updates (no mirrored session)

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
        session.sendMessage(message, replyHandler: nil) { error in
            print("Watch send failed: \(error.localizedDescription)")
        }
    }

    func sendWorkoutEnded() {
        guard let session = session else { return }
        if session.isReachable {
            session.sendMessage(["type": "workoutEnded"], replyHandler: nil) { error in
                print("Watch send failed: \(error.localizedDescription)")
            }
        }
        // Guaranteed delivery fallback — ensures Watch ends session even if screen is off
        session.transferUserInfo(["type": "workoutEnded", "timestamp": Date().timeIntervalSince1970])
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Required for iOS — no action needed
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate after session transfer
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    /// Receives real-time messages from Watch (e.g. WCSession HR fallback when mirroring fails).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        if type == "heartRateUpdate", let hr = message["heartRate"] as? Int {
            Task { @MainActor in
                self.fallbackHeartRate = hr
            }
        } else if type == "watchError", let kind = message["kind"] as? String {
            handleWatchError(kind: kind)
        }
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
