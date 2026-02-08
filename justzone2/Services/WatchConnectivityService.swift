import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchAppInstalled = false
    @Published var watchHeartRate: Int = 0

    private var session: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send to Watch

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

    func sendStartHRSampling() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["type": "startHRSampling"], replyHandler: nil) { error in
            print("Watch send failed: \(error.localizedDescription)")
        }
    }

    func sendStopHRSampling() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["type": "stopHRSampling"], replyHandler: nil) { error in
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

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        if type == "heartRate", let bpm = message["bpm"] as? Int {
            Task { @MainActor in
                self.watchHeartRate = bpm
            }
        }
    }
}
