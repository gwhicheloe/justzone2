import SwiftUI
import Combine
import HealthKit

enum WorkoutState {
    case idle
    case running
    case paused
    case completed
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let heartRate: Int?
    let power: Int?
}

@MainActor
class WorkoutViewModel: ObservableObject {
    @Published var workout: Workout
    @Published var state: WorkoutState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentHeartRate: Int = 0
    @Published var currentPower: Int = 0
    @Published var chartData: [ChartDataPoint] = []
    @Published var healthKitWorkout: HKWorkout?

    // HR source switching
    @Published var useWatchHR: Bool
    @Published var isSwitchingHRSource = false
    @Published var hrSourceError: String?
    @Published var showHRStrapPicker = false

    let bluetoothManager: BluetoothManager
    let kickrService: KickrService
    let heartRateService: HeartRateService
    let healthKitManager: HealthKitManager
    let liveActivityManager: LiveActivityManager
    let watchConnectivityService: WatchConnectivityService

    // MARK: - Zone Targeting
    let zoneTargetingEnabled: Bool
    @Published var adjustedPower: Int = 0
    private var hrBuffer: [Int] = []
    private let hrBufferSize = 45
    private var lastAdjustmentTime: Date?
    private var lastAdjustmentWasDecrease = false
    private var hasReachedZone2 = false
    private let zone2Min: Int
    private let zone2Max: Int
    private let powerStepSize = 5
    private let maxDriftFromTarget = 30
    private let warmUpGracePeriod: TimeInterval = 180
    private let cooldownAfterDecrease: TimeInterval = 90
    private let cooldownAfterIncrease: TimeInterval = 60

    private var timerCancellable: AnyCancellable?
    private var hrCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var workoutStartTime: Date?
    private var powerBuffer: [Int] = []
    private let powerSmoothingWindow = 5

    /// Whether the Watch mirrored session is currently active on the iPhone.
    var isWatchConnected: Bool { healthKitManager.isMirrored }

    init(
        workout: Workout,
        bluetoothManager: BluetoothManager,
        kickrService: KickrService,
        heartRateService: HeartRateService,
        healthKitManager: HealthKitManager,
        liveActivityManager: LiveActivityManager,
        watchConnectivityService: WatchConnectivityService,
        useWatchHR: Bool = false,
        zoneTargetingEnabled: Bool = false
    ) {
        self.workout = workout
        self.bluetoothManager = bluetoothManager
        self.kickrService = kickrService
        self.heartRateService = heartRateService
        self.healthKitManager = healthKitManager
        self.liveActivityManager = liveActivityManager
        self.watchConnectivityService = watchConnectivityService
        self.useWatchHR = useWatchHR
        self.zoneTargetingEnabled = zoneTargetingEnabled
        self.adjustedPower = workout.targetPower

        let z2Min = UserDefaults.standard.integer(forKey: "zone2Min")
        self.zone2Min = z2Min > 0 ? z2Min : 120
        let z2Max = UserDefaults.standard.integer(forKey: "zone2Max")
        self.zone2Max = z2Max > 0 ? z2Max : 140

        setupBindings()
    }

    private func setupBindings() {
        bindHRSource()

        kickrService.$currentPower
            .assign(to: &$currentPower)
    }

    private func bindHRSource() {
        hrCancellable?.cancel()
        if useWatchHR {
            hrCancellable = healthKitManager.$mirroredHeartRate
                .sink { [weak self] hr in self?.currentHeartRate = hr }
        } else {
            hrCancellable = heartRateService.$currentHeartRate
                .sink { [weak self] hr in self?.currentHeartRate = hr }
        }
    }

    // MARK: - HR Source Switching

    func switchToWatchHR() {
        guard !isSwitchingHRSource else { return }
        guard state == .running || state == .paused else { return }

        isSwitchingHRSource = true
        hrSourceError = nil

        Task {
            _ = try? await healthKitManager.endWorkoutSession()

            useWatchHR = true
            bindHRSource()
            launchWatchWorkout()

            isSwitchingHRSource = false
        }
    }

    func switchToBLEHR() {
        guard !isSwitchingHRSource else { return }
        guard state == .running || state == .paused else { return }

        if heartRateService.isConnected {
            completeSwitchToBLE()
        } else {
            startHRStrapSelection()
        }
    }

    func startHRStrapSelection() {
        guard state == .running || state == .paused else { return }
        bluetoothManager.startScanning()
        showHRStrapPicker = true
    }

    func selectAndConnectHRStrap(_ device: DeviceInfo) {
        guard !isSwitchingHRSource else { return }

        if heartRateService.isConnected {
            heartRateService.disconnect()
        }
        heartRateService.connect(to: device)
        showHRStrapPicker = false
        bluetoothManager.stopScanning()

        guard useWatchHR else { return }
        completeSwitchToBLE()
    }

    /// Retry Watch connection from heart button (e.g. if initial launch failed).
    func retryWatchConnection() {
        guard useWatchHR, !isWatchConnected else { return }
        launchWatchWorkout()
    }

    private func completeSwitchToBLE() {
        isSwitchingHRSource = true
        hrSourceError = nil

        Task {
            sendDataToWatch(state: "ended")
            watchConnectivityService.sendStopWorkout()
            healthKitManager.endMirroredSession()

            do {
                try await healthKitManager.startWorkoutSession()
            } catch {
                print("Switch to BLE: failed to start standalone: \(error.localizedDescription)")
                hrSourceError = "Failed to start workout session"
                isSwitchingHRSource = false
                return
            }

            useWatchHR = false
            bindHRSource()
            isSwitchingHRSource = false
        }
    }

    // MARK: - Workout Lifecycle

    func startWorkout() {
        guard state == .idle else { return }

        UIApplication.shared.isIdleTimerDisabled = true

        kickrService.setTargetPower(workout.targetPower)
        kickrService.startWorkout()

        if useWatchHR {
            launchWatchWorkout()
        } else {
            Task {
                do {
                    try await healthKitManager.startWorkoutSession()
                } catch {
                    print("Failed to start HealthKit session: \(error.localizedDescription)")
                }
            }
        }

        do {
            try liveActivityManager.startLiveActivity(
                targetPower: workout.targetPower,
                targetDuration: workout.targetDuration
            )
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }

        workoutStartTime = Date()
        state = .running
        startTimer()
    }

    /// Launch the Watch app and send a start command. Simple two-attempt approach.
    /// The Watch handles mirroring robustness (retry on failure, re-mirror on disconnect).
    private func launchWatchWorkout() {
        Task {
            // Attempt 1
            do {
                try await healthKitManager.startWatchWorkout()
            } catch {
                print("Watch launch attempt 1 failed: \(error.localizedDescription)")
            }
            watchConnectivityService.sendStartWorkout()

            // Wait for mirrored session
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if healthKitManager.isMirrored { return }

            // Attempt 2
            print("Watch not mirrored after 10s, retrying launch...")
            do {
                try await healthKitManager.startWatchWorkout()
            } catch {
                print("Watch launch attempt 2 failed: \(error.localizedDescription)")
            }
        }
    }

    func pauseWorkout() {
        guard state == .running else { return }

        timerCancellable?.cancel()
        timerCancellable = nil
        state = .paused

        kickrService.stopWorkout()

        if useWatchHR {
            sendDataToWatch(state: "paused")
            watchConnectivityService.sendPauseWorkout()
        } else {
            healthKitManager.pauseWorkoutSession()
            sendWatchDisplayUpdate(state: "paused")
        }

        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: true
        )
    }

    func resumeWorkout() {
        guard state == .paused else { return }

        kickrService.startWorkout()
        kickrService.setTargetPower(adjustedPower)
        lastAdjustmentTime = Date()
        state = .running

        if useWatchHR {
            sendDataToWatch(state: "running")
            watchConnectivityService.sendResumeWorkout()
        } else {
            healthKitManager.resumeWorkoutSession()
            sendWatchDisplayUpdate(state: "running")
        }

        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: false
        )

        startTimer()
    }

    func stopWorkout() {
        timerCancellable?.cancel()
        timerCancellable = nil

        workout.finish()
        state = .completed

        kickrService.stopWorkout()

        if useWatchHR {
            sendDataToWatch(state: "ended")
            watchConnectivityService.sendStopWorkout()
            healthKitManager.endMirroredSession()
        } else {
            Task {
                do {
                    healthKitWorkout = try await healthKitManager.endWorkoutSession()
                } catch {
                    print("Failed to end HealthKit session: \(error.localizedDescription)")
                }
            }
            watchConnectivityService.sendWorkoutEnded()
        }

        liveActivityManager.endLiveActivity()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: Constants.sampleInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.timerTick()
                }
            }
    }

    private func timerTick() {
        guard state == .running else { return }
        guard !isSwitchingHRSource else { return }

        let now = Date()

        if let startTime = workoutStartTime {
            elapsedTime = now.timeIntervalSince(startTime)
        }

        let hr = currentHeartRate > 0 ? currentHeartRate : nil
        let pwr = currentPower > 0 ? currentPower : nil

        workout.addSample(heartRate: hr, power: pwr)
        evaluateZoneTargeting()

        if useWatchHR && healthKitManager.isMirrored {
            // Mode A (connected): Data flows through mirrored session
            sendDataToWatch(state: "running")
            if let power = pwr {
                healthKitManager.addPowerToMirroredBuilder(power, at: now)
            }
        } else if useWatchHR {
            // Mode A (not yet connected): Send display updates via WCSession so Watch shows data
            sendWatchDisplayUpdate(state: "running")
        } else {
            // Mode B: Record to standalone HealthKit session
            if let heartRate = hr {
                healthKitManager.addHeartRateSample(heartRate, at: now)
            }
            if let power = pwr {
                healthKitManager.addPowerSample(power, at: now)
            }
            sendWatchDisplayUpdate(state: "running")
        }

        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: false
        )

        // Chart data with smoothed power
        if let power = pwr {
            powerBuffer.append(power)
            if powerBuffer.count > powerSmoothingWindow {
                powerBuffer.removeFirst(powerBuffer.count - powerSmoothingWindow)
            }
        }
        let smoothedPower = powerBuffer.isEmpty ? pwr : powerBuffer.reduce(0, +) / powerBuffer.count
        chartData.append(ChartDataPoint(
            time: elapsedTime,
            heartRate: hr,
            power: smoothedPower
        ))

        if elapsedTime >= workout.targetDuration {
            stopWorkout()
        }
    }

    // MARK: - Watch Data

    private func sendDataToWatch(state: String) {
        let data = PhoneToWatchData(
            power: currentPower,
            elapsedTime: elapsedTime,
            chunkRemaining: timeRemainingInChunk,
            currentChunk: currentChunk,
            totalChunks: totalChunks,
            adjustedPower: adjustedPower,
            targetPower: workout.targetPower,
            state: state
        )
        healthKitManager.sendDataToWatch(data)
    }

    /// Send display-only updates to Watch via WCSession (used when mirrored session isn't active).
    private func sendWatchDisplayUpdate(state: String) {
        watchConnectivityService.sendWorkoutUpdate(
            heartRate: currentHeartRate,
            power: currentPower,
            elapsedTime: elapsedTime,
            chunkRemaining: timeRemainingInChunk,
            currentChunk: currentChunk,
            totalChunks: totalChunks,
            state: state
        )
    }

    var progress: Double {
        guard workout.targetDuration > 0 else { return 0 }
        return min(elapsedTime / workout.targetDuration, 1.0)
    }

    var remainingTime: TimeInterval {
        max(workout.targetDuration - elapsedTime, 0)
    }

    // MARK: - Chunk-based timing (10-minute chunks)

    var chunkDuration: TimeInterval { 10 * 60 }

    var currentChunk: Int {
        min(Int(elapsedTime / chunkDuration) + 1, totalChunks)
    }

    var totalChunks: Int {
        max(1, Int(ceil(workout.targetDuration / chunkDuration)))
    }

    var timeRemainingInChunk: TimeInterval {
        if currentChunk == totalChunks {
            return remainingTime
        }
        let timeInCurrentChunk = elapsedTime.truncatingRemainder(dividingBy: chunkDuration)
        return chunkDuration - timeInCurrentChunk
    }

    // MARK: - Zone Targeting

    private func evaluateZoneTargeting() {
        guard zoneTargetingEnabled else { return }
        guard currentHeartRate > 0 else { return }

        hrBuffer.append(currentHeartRate)
        if hrBuffer.count > hrBufferSize {
            hrBuffer.removeFirst(hrBuffer.count - hrBufferSize)
        }

        guard elapsedTime >= warmUpGracePeriod else { return }
        guard hrBuffer.count >= hrBufferSize else { return }

        let smoothedHR = hrBuffer.reduce(0, +) / hrBuffer.count

        if smoothedHR >= zone2Min && smoothedHR <= zone2Max {
            hasReachedZone2 = true
            return
        }

        // Don't increase power until HR has entered Zone 2 at least once.
        // During warm-up, HR naturally rises — increasing power prematurely
        // causes overshoot once the body catches up.
        if smoothedHR < zone2Min && !hasReachedZone2 {
            return
        }

        let now = Date()
        if let lastAdj = lastAdjustmentTime {
            let requiredCooldown = lastAdjustmentWasDecrease
                ? cooldownAfterDecrease
                : cooldownAfterIncrease
            guard now.timeIntervalSince(lastAdj) >= requiredCooldown else { return }
        }

        var newPower = adjustedPower

        if smoothedHR > zone2Max {
            newPower -= powerStepSize
            lastAdjustmentWasDecrease = true
        } else if smoothedHR < zone2Min {
            newPower += powerStepSize
            lastAdjustmentWasDecrease = false
        }

        let lowerBound = workout.targetPower - maxDriftFromTarget
        let upperBound = workout.targetPower + maxDriftFromTarget
        newPower = max(max(lowerBound, 50), min(upperBound, newPower))

        if newPower != adjustedPower {
            adjustedPower = newPower
            kickrService.setTargetPower(adjustedPower)
            lastAdjustmentTime = now
        }
    }

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
