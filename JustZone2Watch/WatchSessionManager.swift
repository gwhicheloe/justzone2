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

    private var wcSession: WCSession?
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    override init() {
        super.init()

        // Set up WCSession for receiving start/stop commands and Mode B display updates
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }

        // Handle launch from iPhone via startWatchApp(with:)
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            Task { @MainActor in
                self?.handleStartFromPhone(session: mirroredSession)
            }
        }
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

    // MARK: - Primary Workout Session

    /// Called when iPhone launches this app via startWatchApp(with:).
    /// The system provides a pre-configured session that we start and mirror back.
    private func handleStartFromPhone(session: HKWorkoutSession) {
        guard workoutSession == nil else { return }

        self.workoutSession = session
        session.delegate = self

        let builder = session.associatedWorkoutBuilder()
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: session.workoutConfiguration
        )
        self.workoutBuilder = builder

        session.startActivity(with: Date())
        Task {
            do {
                try await builder.beginCollection(at: Date())
            } catch {
                print("Watch builder beginCollection failed: \(error.localizedDescription)")
            }
            try await session.startMirroringToCompanionDevice()
        }

        self.workoutState = "running"
    }

    /// Start a primary workout session (called from WCSession message as backup).
    func startPrimaryWorkout() {
        guard workoutSession == nil else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            self.workoutSession = session

            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            Task {
                do {
                    try await builder.beginCollection(at: Date())
                } catch {
                    print("Watch builder beginCollection failed: \(error.localizedDescription)")
                }
                try await session.startMirroringToCompanionDevice()
            }

            self.workoutState = "running"
        } catch {
            print("Watch workout session creation failed: \(error.localizedDescription)")
        }
    }

    func endPrimaryWorkout() {
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        session.stopActivity(with: Date())

        Task {
            do {
                try await builder.endCollection(at: Date())
                try await builder.finishWorkout()
            } catch {
                print("Watch workout end failed: \(error.localizedDescription)")
            }
            session.end()
            self.workoutSession = nil
            self.workoutBuilder = nil
            self.workoutState = "ended"
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

// MARK: - HKWorkoutSessionDelegate

extension WatchSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.workoutState = "running"
            case .paused:
                self.workoutState = "paused"
            case .stopped:
                // Don't set "ended" here — wait for endPrimaryWorkout to finish saving
                break
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("Watch workout session failed: \(error.localizedDescription)")
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor in
            for datum in data {
                guard let update = try? JSONDecoder().decode(PhoneToWatchData.self, from: datum) else { continue }

                self.power = update.power
                self.elapsedTime = update.elapsedTime
                self.chunkRemaining = update.chunkRemaining
                self.currentChunk = update.currentChunk
                self.totalChunks = update.totalChunks

                // Handle state changes from iPhone
                switch update.state {
                case "paused":
                    if workoutSession.state == .running {
                        workoutSession.pause()
                    }
                case "running":
                    if workoutSession.state == .paused {
                        workoutSession.resume()
                    }
                case "ended":
                    self.endPrimaryWorkout()
                default:
                    break
                }
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        if let error = error {
            print("Watch disconnected from iPhone: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            let hrType = HKQuantityType(.heartRate)
            guard collectedTypes.contains(hrType) else { return }

            if let stats = workoutBuilder.statistics(for: hrType),
               let quantity = stats.mostRecentQuantity() {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = Int(quantity.doubleValue(for: unit))
                self.heartRate = bpm
            }
        }
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
            case "startWorkout":
                // Backup trigger from iPhone (in case startWatchApp didn't fire the handler)
                await self.requestAuthorization()
                self.startPrimaryWorkout()

            case "stopWorkout":
                // Backup stop signal from iPhone
                self.endPrimaryWorkout()

            case "pauseWorkout":
                self.workoutSession?.pause()

            case "resumeWorkout":
                self.workoutSession?.resume()

            case "workoutUpdate":
                // Mode B: display-only updates when Watch is passive (no primary session)
                guard self.workoutSession == nil else { return }
                self.heartRate = message["heartRate"] as? Int ?? self.heartRate
                self.power = message["power"] as? Int ?? self.power
                self.elapsedTime = message["elapsedTime"] as? TimeInterval ?? self.elapsedTime
                self.chunkRemaining = message["chunkRemaining"] as? TimeInterval ?? self.chunkRemaining
                self.currentChunk = message["currentChunk"] as? Int ?? self.currentChunk
                self.totalChunks = message["totalChunks"] as? Int ?? self.totalChunks
                self.workoutState = message["state"] as? String ?? self.workoutState

            case "workoutEnded":
                // Mode B: display-only
                guard self.workoutSession == nil else { return }
                self.workoutState = "ended"

            default:
                break
            }
        }
    }
}
