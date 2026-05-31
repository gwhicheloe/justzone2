import Foundation
import HealthKit

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()

    /// The single iPhone-side workout session. Used for both Mode A (Watch HR
    /// shipped over WCSession) and Mode B (BLE HR strap on iPhone). HR samples
    /// are added manually via addHeartRateSample regardless of source.
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var sessionState: HKWorkoutSessionState = .notStarted

    /// HR samples collected by HKLiveWorkoutDataSource — used for AirPods Pro 3,
    /// which pushes HR into the user's HealthKit store and the builder picks it
    /// up automatically. Zero for non-native sources (Watch over WCSession,
    /// BLE strap via heartRateService).
    @Published var builderHeartRate: Int = 0
    /// True once at least one native HR sample has arrived for this workout.
    @Published var hasReceivedBuilderHR: Bool = false

    private var builderHRCount = 0

    /// True only while a live HR data source is attached (AirPods). Used to
    /// detect the regression where iOS commandeers the Watch to feed HR into
    /// the builder even though we never attached a data source.
    private var liveHRSourceEnabled = false
    private var loggedUnexpectedBuilderHR = false

    var isStandaloneSessionActive: Bool { workoutSession != nil }

    override init() {
        super.init()
        checkAuthorizationStatus()
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

    // MARK: - Watch App Launch

    /// Launch the Watch app via HealthKit. This is the only way for an iOS app
    /// to wake a paired Watch app — the Watch's `workoutSessionMirroringStartHandler`
    /// fires and the Watch starts its own HR-collecting session. We do not open
    /// the mirrored data channel; HR flows back via WCSession instead.
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

    /// Launch the Watch app in display-only mode (Mode B). `.outdoor` is the
    /// signal to the Watch to skip its builder/recording.
    func startWatchDisplayApp() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor
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

    // MARK: - iPhone Workout Session (single, used for all modes)

    /// Start the iPhone-owned workout session (background execution + record sink).
    ///
    /// - Parameter collectLiveHR: attach an `HKLiveWorkoutDataSource` so the
    ///   builder auto-collects heart rate. This is **only** wanted for AirPods,
    ///   where in-ear HR lands in the HealthKit store. It must NOT be attached
    ///   for the Apple Watch source: an iPhone has no HR sensor, so a live
    ///   cycling data source makes iOS commandeer the paired Watch to supply HR
    ///   — which starts a competing Watch workout and blocks our own Watch app's
    ///   session from starting ("another session is in progress"). That was the
    ///   AirPods regression that broke Watch HR.
    func startWorkoutSession(collectLiveHR: Bool = false) async throws {
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

            if collectLiveHR {
                workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                    healthStore: healthStore,
                    workoutConfiguration: configuration
                )
            }
            liveHRSourceEnabled = collectLiveHR
            loggedUnexpectedBuilderHR = false

            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)
            dlog("[IPHONE-HK] startWorkoutSession — session running, builder collecting (liveHR=\(collectLiveHR))")
        } catch {
            dlog("[IPHONE-HK] startWorkoutSession FAILED: \(error.localizedDescription)")
            throw HealthKitError.sessionStartFailed(error.localizedDescription)
        }
    }

    /// Attach a live HR data source to the already-running builder — used when
    /// the user switches to AirPods mid-workout (the session started without one
    /// because the original source was Watch/BLE).
    func attachLiveHRCollection() {
        guard let builder = workoutBuilder, builder.dataSource == nil else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .indoor
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        liveHRSourceEnabled = true
        dlog("[IPHONE-HK] attachLiveHRCollection — live HR data source attached mid-workout")
    }

    /// Detach the live HR data source — used when switching AWAY from AirPods to
    /// the Watch, so iOS stops pulling HR from the Watch and frees it to run our
    /// own Watch app session.
    func detachLiveHRCollection() {
        guard let builder = workoutBuilder, builder.dataSource != nil else { return }
        builder.dataSource = nil
        liveHRSourceEnabled = false
        dlog("[IPHONE-HK] detachLiveHRCollection — live HR data source removed")
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
            dlog("[IPHONE-HK] endWorkoutSession — saved to HealthKit")

            return workout
        } catch {
            dlog("[IPHONE-HK] endWorkoutSession FAILED: \(error.localizedDescription)")
            throw HealthKitError.sessionEndFailed(error.localizedDescription)
        }
    }

    // MARK: - Sample Collection

    /// Add an HR sample to the active workout builder.
    /// Source-agnostic: caller passes HR from Watch (WCSession) or BLE strap.
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
                dlog("[IPHONE-HK] addHeartRateSample FAILED: \(error.localizedDescription)")
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
                dlog("[IPHONE-HK] addPowerSample FAILED: \(error.localizedDescription)")
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
            let from = hkStateName(fromState)
            let to = hkStateName(toState)
            dlog("[IPHONE-HK] session state: \(from) → \(to)")
            dsignpost("iPhone session \(to)")
            self.sessionState = toState
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        dlog("[IPHONE-HK] session FAILED: \(error.localizedDescription)")
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
        let hrType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(hrType) else { return }
        guard let stats = workoutBuilder.statistics(for: hrType),
              let quantity = stats.mostRecentQuantity() else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = Int(quantity.doubleValue(for: unit))
        guard bpm > 0 else { return }

        Task { @MainActor in
            // Anomaly detector: builder HR while no live data source is attached
            // means iOS is commandeering the Watch to feed HR — the exact bug
            // that breaks Watch HR. Log it loudly, once per workout.
            if !self.liveHRSourceEnabled && !self.loggedUnexpectedBuilderHR {
                self.loggedUnexpectedBuilderHR = true
                dlog("[IPHONE-HK] ⚠️ ANOMALY — builder HR=\(bpm) with NO live data source attached; iOS may be commandeering the Watch")
            }
            if !self.hasReceivedBuilderHR {
                self.hasReceivedBuilderHR = true
                dlog("[IPHONE-HK] HR first received via builder — bpm=\(bpm)")
            }
            self.builderHeartRate = bpm
            self.builderHRCount += 1
            if self.builderHRCount % 30 == 0 {
                dlog("[IPHONE-HK] HR builder rollup — received=\(self.builderHRCount) bpm=\(bpm)")
            }
            dsignpost("Builder HR=\(bpm) count=\(self.builderHRCount)")
        }
    }
}

extension HealthKitManager {
    /// Reset builder-HR counters at the start of a workout.
    func resetBuilderHRStats() {
        builderHeartRate = 0
        hasReceivedBuilderHR = false
        builderHRCount = 0
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
