import Foundation
import HealthKit

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var sessionState: HKWorkoutSessionState = .notStarted

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

    // MARK: - Workout Session

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

    // MARK: - Sample Collection

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

        workoutBuilder?.add([sample]) { success, error in
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

        workoutBuilder?.add([sample]) { success, error in
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
        // Handle collected data if needed
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
