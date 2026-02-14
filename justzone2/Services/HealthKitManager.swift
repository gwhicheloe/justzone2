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
    @Published var mirroredHeartRate: Int = 0
    @Published var mirroredSessionDisconnected = false
    private var reconnecting = false

    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var sessionState: HKWorkoutSessionState = .notStarted

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
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor
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

    /// Called when the Watch mirrors its primary session to this iPhone.
    private func handleMirroredSession(_ session: HKWorkoutSession) {
        // Clean up any previous mirrored session
        self.mirroredSession = session
        session.delegate = self

        let builder = session.associatedWorkoutBuilder()
        builder.delegate = self
        self.mirroredBuilder = builder

        // Clear reconnection state
        if reconnecting {
            reconnecting = false
        }
        mirroredSessionDisconnected = false

        sessionState = .running
    }

    /// Attempt to reconnect a lost mirrored session by re-launching the Watch app.
    private func attemptReconnection() {
        guard !reconnecting else { return }
        reconnecting = true

        Task {
            // Wait briefly for Watch to finish restarting
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Try to re-launch Watch app
            do {
                try await startWatchWorkout()
            } catch {
                print("Reconnection: failed to launch Watch app: \(error.localizedDescription)")
            }

            // Wait up to 10 seconds for mirrored session to arrive
            try? await Task.sleep(nanoseconds: 10_000_000_000)

            // If still reconnecting after timeout, give up
            if reconnecting {
                reconnecting = false
                // mirroredSessionDisconnected stays true — WorkoutViewModel can offer switch to BLE
            }
        }
    }

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
        reconnecting = false
        mirroredSessionDisconnected = false
        mirroredSession = nil
        mirroredBuilder = nil
        mirroredHeartRate = 0
        sessionState = .notStarted
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
            self.sessionState = toState
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("Workout session failed: \(error.localizedDescription)")
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Watch could send data here if needed in the future
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("Mirrored session disconnected: \(error.localizedDescription)")
            }

            // Only attempt reconnection if we had an active mirrored session
            guard self.mirroredSession != nil else { return }

            self.mirroredSessionDisconnected = true
            self.mirroredHeartRate = 0
            self.mirroredSession = nil
            self.mirroredBuilder = nil

            self.attemptReconnection()
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
