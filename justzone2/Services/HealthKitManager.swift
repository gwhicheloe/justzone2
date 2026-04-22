import Foundation
import HealthKit

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()

    // Mode B: Standalone session (iPhone creates its own)
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // Mode A: Mirrored session (received from Watch)
    private var mirroredSession: HKWorkoutSession?
    private var mirroredBuilder: HKLiveWorkoutBuilder?

    // Mode A: Background execution session (keeps iPhone alive while Watch records HR)
    private var backgroundSession: HKWorkoutSession?
    @Published var mirroredHeartRate: Int = 0
    @Published var mirroredSessionDisconnected = false

    // Recovery: mirrored session held pending user confirmation
    private var pendingRecoverySession: HKWorkoutSession?
    @Published var pendingRecovery: WorkoutRecovery?

    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var sessionState: HKWorkoutSessionState = .notStarted

    /// Set by WorkoutViewModel when a workout is actively running.
    /// Used to detect orphaned sessions on background relaunch.
    var isWorkoutActive = false

    var isStandaloneSessionActive: Bool { workoutSession != nil }

    override init() {
        super.init()
        checkAuthorizationStatus()

        // Mode A: Receive mirrored session from Watch
        healthStore.workoutSessionMirroringStartHandler = { [weak self] session in
            Task { @MainActor in
                self?.handleMirroredSession(session)
            }
        }
    }

    // MARK: - Authorization

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var typesToWrite: Set<HKSampleType> {
        [
            HKWorkoutType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.cyclingPower),
            HKQuantityType(.activeEnergyBurned)
        ]
    }

    private var typesToRead: Set<HKObjectType> {
        [
            HKQuantityType(.heartRate)
        ]
    }

    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            isAuthorized = false
            return
        }

        let workoutType = HKWorkoutType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = status == .sharingAuthorized
    }

    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            checkAuthorizationStatus()
        } catch {
            authorizationError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Mode A: Mirrored Session (Watch HR)

    /// Launch the Watch app and trigger workout session mirroring.
    func startWatchWorkout() async throws {
        dlog("[IPHONE-HK] startWatchWorkout — calling startWatchApp(.indoor)")
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.startWatchApp(with: config) { success, error in
                if let error = error {
                    dlog("[IPHONE-HK] startWatchApp FAILED: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    dlog("[IPHONE-HK] startWatchApp succeeded (success=\(success))")
                    continuation.resume()
                }
            }
        }
    }

    /// Called when the Watch mirrors its primary session to this iPhone.
    private func handleMirroredSession(_ session: HKWorkoutSession) {
        dlog("[IPHONE-HK] handleMirroredSession — mirrored session received from Watch (isWorkoutActive=\(isWorkoutActive))")

        guard isWorkoutActive else {
            // Check if this is a recoverable killed-session
            if let local = LocalWorkoutStore.shared.mostRecentInProgress() {
                dlog("[IPHONE-HK] handleMirroredSession — no active workout but saved state found, holding for recovery")
                pendingRecoverySession = session
                pendingRecovery = WorkoutRecovery(
                    targetPower: local.workout.targetPower,
                    targetDuration: local.workout.targetDuration,
                    elapsedTime: local.elapsedTime,
                    useWatchHR: local.useWatchHR,
                    zoneTargetingEnabled: local.zoneTargetingEnabled,
                    warmUpEnabled: local.warmUpEnabled
                )
            } else {
                dlog("[IPHONE-HK] handleMirroredSession — no active workout, ending orphaned session")
                session.end()
            }
            return
        }

        setupMirroredSession(session)
    }

    private func setupMirroredSession(_ session: HKWorkoutSession) {
        self.mirroredSession = session
        session.delegate = self

        let builder = session.associatedWorkoutBuilder()
        builder.delegate = self
        self.mirroredBuilder = builder

        mirroredSessionDisconnected = false
        sessionState = .running
        dlog("[IPHONE-HK] mirrored session set up — isMirrored=true")
    }

    /// Called when the user confirms recovery. Sets up the pending session as the active mirrored session.
    func claimPendingRecovery() {
        guard let session = pendingRecoverySession else { return }
        setupMirroredSession(session)
        pendingRecoverySession = nil
        pendingRecovery = nil
        dlog("[IPHONE-HK] claimPendingRecovery — mirrored session claimed for recovery")
    }

    /// Called when the user discards the recovery. Ends the pending session.
    func discardPendingRecovery() {
        pendingRecoverySession?.end()
        pendingRecoverySession = nil
        pendingRecovery = nil
        if let local = LocalWorkoutStore.shared.mostRecentInProgress() {
            LocalWorkoutStore.shared.delete(id: local.id)
        }
        dlog("[IPHONE-HK] discardPendingRecovery — orphaned session ended")
    }

    // Reconnection is handled by WorkoutViewModel's persistent Watch connection loop.
    // HealthKitManager just sets the disconnected flag; the ViewModel detects isMirrored == false
    // and retries startWatchWorkout() automatically.

    /// Send workout data to Watch via the mirrored session's data channel.
    func sendDataToWatch(_ data: PhoneToWatchData) {
        guard let session = mirroredSession else { return }
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        Task {
            try? await session.sendToRemoteWorkoutSession(data: encoded)
        }
    }

    /// Add power sample to the mirrored builder (iPhone contributes power data).
    func addPowerToMirroredBuilder(_ power: Int, at date: Date) {
        guard power > 0, let builder = mirroredBuilder else { return }

        let powerType = HKQuantityType(.cyclingPower)
        let powerUnit = HKUnit.watt()
        let quantity = HKQuantity(unit: powerUnit, doubleValue: Double(power))
        let sample = HKQuantitySample(
            type: powerType,
            quantity: quantity,
            start: date,
            end: date
        )

        builder.add([sample]) { _, error in
            if let error = error {
                print("Failed to add power to mirrored builder: \(error.localizedDescription)")
            }
        }
    }

    /// Whether a mirrored session is active (Mode A).
    var isMirrored: Bool {
        mirroredSession != nil
    }

    /// Clean up the mirrored session.
    func endMirroredSession() {
        mirroredSessionDisconnected = false
        mirroredSession = nil
        mirroredBuilder = nil
        mirroredHeartRate = 0
        sessionState = .notStarted
    }

    // MARK: - Mode A: Background Execution Session

    /// Start a minimal HKWorkoutSession on the iPhone purely for background execution protection.
    /// No builder or data source — this session exists only to prevent iOS from killing the app.
    func startBackgroundSession() async {
        guard backgroundSession == nil else {
            dlog("[IPHONE-HK] startBackgroundSession — already active, skipping")
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            self.backgroundSession = session
            session.startActivity(with: Date())
            dlog("[IPHONE-HK] startBackgroundSession — session started for background execution")
        } catch {
            dlog("[IPHONE-HK] startBackgroundSession FAILED: \(error.localizedDescription)")
        }
    }

    /// End the background execution session. No workout is saved.
    func endBackgroundSession() {
        guard let session = backgroundSession else { return }
        session.end()
        self.backgroundSession = nil
        dlog("[IPHONE-HK] endBackgroundSession — session ended")
    }

    /// Launch the Watch app in display-only mode (Mode B: BLE HR strap on iPhone).
    /// Uses .outdoor locationType as a signal to the Watch to skip builder/recording.
    func startWatchDisplayApp() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor  // Signal: display-only, no HR recording on Watch
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.startWatchApp(with: config) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Mode B: Standalone Session (BLE HR)

    func startWorkoutSession() async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self

            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

        } catch {
            throw HealthKitError.sessionStartFailed(error.localizedDescription)
        }
    }

    func pauseWorkoutSession() {
        workoutSession?.pause()
    }

    func resumeWorkoutSession() {
        workoutSession?.resume()
    }

    func endWorkoutSession() async throws -> HKWorkout? {
        guard let workoutSession = workoutSession,
              let workoutBuilder = workoutBuilder else {
            return nil
        }

        let endDate = Date()
        workoutSession.end()

        do {
            try await workoutBuilder.endCollection(at: endDate)
            let workout = try await workoutBuilder.finishWorkout()

            self.workoutSession = nil
            self.workoutBuilder = nil
            sessionState = .notStarted

            return workout
        } catch {
            throw HealthKitError.sessionEndFailed(error.localizedDescription)
        }
    }

    // MARK: - Mode B: Sample Collection

    func addHeartRateSample(_ heartRate: Int, at date: Date) {
        guard heartRate > 0 else { return }

        let heartRateType = HKQuantityType(.heartRate)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let quantity = HKQuantity(unit: heartRateUnit, doubleValue: Double(heartRate))
        let sample = HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: date,
            end: date
        )

        workoutBuilder?.add([sample]) { _, error in
            if let error = error {
                print("Failed to add heart rate sample: \(error.localizedDescription)")
            }
        }
    }

    func addPowerSample(_ power: Int, at date: Date) {
        guard power > 0 else { return }

        let powerType = HKQuantityType(.cyclingPower)
        let powerUnit = HKUnit.watt()
        let quantity = HKQuantity(unit: powerUnit, doubleValue: Double(power))
        let sample = HKQuantitySample(
            type: powerType,
            quantity: quantity,
            start: date,
            end: date
        )

        workoutBuilder?.add([sample]) { _, error in
            if let error = error {
                print("Failed to add power sample: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            if workoutSession === self.backgroundSession {
                dlog("[IPHONE-HK] background session state: \(fromState.rawValue) → \(toState.rawValue)")
                // Don't update sessionState for the background session
            } else {
                dlog("[IPHONE-HK] session state: \(fromState.rawValue) → \(toState.rawValue)")
                self.sessionState = toState
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            if workoutSession === self.backgroundSession {
                dlog("[IPHONE-HK] background session FAILED: \(error.localizedDescription)")
            } else {
                dlog("[IPHONE-HK] session FAILED: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor in
            for datum in data {
                guard let update = try? JSONDecoder().decode(WatchToPhoneData.self, from: datum) else {
                    dlog("[IPHONE-HK] didReceiveDataFromRemote: decode failed")
                    continue
                }
                self.mirroredHeartRate = update.heartRate
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        Task { @MainActor in
            if workoutSession === self.backgroundSession {
                dlog("[IPHONE-HK] background session disconnected (expected, ignoring)")
                return
            }

            dlog("[IPHONE-HK] mirrored session disconnected: \(error?.localizedDescription ?? "no error")")
            // Only attempt reconnection if we had an active mirrored session
            guard self.mirroredSession != nil else { return }

            self.mirroredSessionDisconnected = true
            self.mirroredHeartRate = 0
            self.mirroredSession = nil
            self.mirroredBuilder = nil
            dlog("[IPHONE-HK] mirrored session cleared — WorkoutViewModel will retry")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            // Only extract HR from the mirrored builder (Mode A)
            guard workoutBuilder === self.mirroredBuilder else { return }

            let hrType = HKQuantityType(.heartRate)
            guard collectedTypes.contains(hrType) else { return }

            if let stats = workoutBuilder.statistics(for: hrType),
               let quantity = stats.mostRecentQuantity() {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = Int(quantity.doubleValue(for: unit))
                self.mirroredHeartRate = bpm
            }
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case sessionStartFailed(String)
    case sessionEndFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .notAuthorized:
            return "HealthKit authorization is required to record workouts."
        case .sessionStartFailed(let message):
            return "Failed to start workout session: \(message)"
        case .sessionEndFailed(let message):
            return "Failed to end workout session: \(message)"
        }
    }
}
