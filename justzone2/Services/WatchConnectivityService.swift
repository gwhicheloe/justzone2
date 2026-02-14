import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchAppInstalled = false

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
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["type": "workoutEnded"], replyHandler: nil) { error in
            print("Watch send failed: \(error.localizedDescription)")
        }
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
}
