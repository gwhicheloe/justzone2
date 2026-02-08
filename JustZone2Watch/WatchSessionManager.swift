import WatchConnectivity
import HealthKit

@MainActor
class WatchSessionManager: NSObject, ObservableObject {
    @Published var heartRate: Int = 0
    @Published var power: Int = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var chunkRemaining: TimeInterval = 0
    @Published var currentChunk: Int = 0
    @Published var totalChunks: Int = 0
    @Published var workoutState: String = "idle"
    @Published var isPhoneReachable = false

    private var session: WCSession?
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var heartRateQuery: HKAnchoredObjectQuery?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - HealthKit Authorization

    func requestAuthorization() async {
        let typesToRead: Set<HKObjectType> = [HKQuantityType(.heartRate)]
        let typesToWrite: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        } catch {
            print("Watch HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - HR Sampling

    func startHRSampling() {
        // Need a workout session on Watch for continuous HR access
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutSession?.startActivity(with: Date())
        } catch {
            print("Watch workout session failed: \(error.localizedDescription)")
            return
        }

        // Query for HR updates
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil)

        heartRateQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHRSamples(samples)
            }
        }

        heartRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHRSamples(samples)
            }
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }

    func stopHRSampling() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        workoutSession?.end()
        workoutSession = nil
    }

    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = Int(latest.quantity.doubleValue(for: unit))

        self.heartRate = bpm
        self.sendHRToPhone(bpm)
    }

    private func sendHRToPhone(_ bpm: Int) {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(
            ["type": "heartRate", "bpm": bpm],
            replyHandler: nil
        ) { error in
            print("Watch HR send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Time Formatting

    func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        Task { @MainActor in
            switch type {
            case "workoutUpdate":
                self.heartRate = message["heartRate"] as? Int ?? self.heartRate
                self.power = message["power"] as? Int ?? self.power
                self.elapsedTime = message["elapsedTime"] as? TimeInterval ?? self.elapsedTime
                self.chunkRemaining = message["chunkRemaining"] as? TimeInterval ?? self.chunkRemaining
                self.currentChunk = message["currentChunk"] as? Int ?? self.currentChunk
                self.totalChunks = message["totalChunks"] as? Int ?? self.totalChunks
                self.workoutState = message["state"] as? String ?? self.workoutState

            case "workoutEnded":
                self.workoutState = "ended"

            case "startHRSampling":
                await self.requestAuthorization()
                self.startHRSampling()

            case "stopHRSampling":
                self.stopHRSampling()

            default:
                break
            }
        }
    }
}
