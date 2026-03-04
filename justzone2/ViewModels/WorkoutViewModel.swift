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

    // MARK: - Warm Up & Cool Down
    let warmUpEnabled: Bool
    private let warmUpDuration: TimeInterval = 60
    private var warmUpComplete = false

    var isWarmingUp: Bool {
        warmUpEnabled && state == .running && !warmUpComplete
    }

    var warmUpRemaining: TimeInterval {
        max(warmUpDuration - elapsedTime, 0)
    }

    // MARK: - Zone Targeting
    @Published var zoneTargetingEnabled: Bool {
        didSet { if zoneTargetingEnabled { resetPID() } }
    }
    @Published var adjustedPower: Int = 0
    private var hrBuffer: [Int] = []
    private let hrBufferSize = 45
    private var hasReachedZone2 = false
    private let zone2Min: Int
    private let zone2Max: Int
    private let maxDriftFromTarget = 30
    private let warmUpGracePeriod: TimeInterval = 180

    // PID state
    private let pidKp: Double = 0.5            // W/bpm
    private let pidKi: Double = 0.008          // W/(bpm·s)
    private var pidIntegral: Double = 0
    private var pidOutputWatts: Double = 0
    // Rate limits — increase slowly (athlete settling), decrease faster (safety)
    private let pidMaxRateIncrease: Double = 5.0 / 90.0  // 5W per 90s
    private let pidMaxRateDecrease: Double = 5.0 / 45.0  // 5W per 45s

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
        zoneTargetingEnabled: Bool = false,
        warmUpEnabled: Bool = false
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
        self.warmUpEnabled = warmUpEnabled
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

        let startPower = warmUpEnabled ? workout.targetPower / 2 : workout.targetPower
        kickrService.setTargetPower(startPower)
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
            // Start a display-only session on the Watch so it stays alive in the
            // background and can receive workout updates via WCSession
            watchConnectivityService.sendStartDisplayWorkout()
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
        let resumePower = warmUpEnabled && !warmUpComplete ? workout.targetPower / 2 : adjustedPower
        kickrService.setTargetPower(resumePower)
        resetPID()
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

    private func startCooldown() {
        timerCancellable?.cancel()
        timerCancellable = nil

        workout.finish()

        // Leave KICKR running at half power so rider can cool down while viewing summary
        kickrService.setTargetPower(workout.targetPower / 2)

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

        state = .completed
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

        // Warm-up → full power transition
        if warmUpEnabled && !warmUpComplete && elapsedTime >= warmUpDuration {
            warmUpComplete = true
            kickrService.setTargetPower(adjustedPower)
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
            startCooldown()
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

    // MARK: - Zone Targeting (PID)

    private func resetPID() {
        pidIntegral = 0
        pidOutputWatts = Double(adjustedPower - workout.targetPower)
    }

    private func evaluateZoneTargeting() {
        guard zoneTargetingEnabled else { return }
        guard currentHeartRate > 0 else { return }

        hrBuffer.append(currentHeartRate)
        if hrBuffer.count > hrBufferSize {
            hrBuffer.removeFirst(hrBuffer.count - hrBufferSize)
        }

        // Grace period — let HR settle before PID engages
        guard elapsedTime >= warmUpGracePeriod else { return }
        guard hrBuffer.count >= hrBufferSize else { return }

        let smoothedHR = Double(hrBuffer.reduce(0, +)) / Double(hrBuffer.count)
        let setpoint = Double(zone2Min + zone2Max) / 2.0

        if smoothedHR >= Double(zone2Min) && smoothedHR <= Double(zone2Max) {
            hasReachedZone2 = true
        }

        // error > 0  → HR below zone → need more power
        // error < 0  → HR above zone → need less power
        let error = setpoint - smoothedHR

        // Early settling phase (3–10 min, before HR has ever reached zone):
        // don't accumulate integral — prevents windup from building while we
        // block power increases, which would cause a sudden surge when released
        let inEarlyPhase = !hasReachedZone2 && elapsedTime < 10 * 60
        if !inEarlyPhase {
            pidIntegral += error * Constants.sampleInterval
            // Anti-windup clamp
            let maxIntegral = Double(maxDriftFromTarget) / max(pidKi, 0.001)
            pidIntegral = max(-maxIntegral, min(maxIntegral, pidIntegral))
        }

        let rawOutput = pidKp * error + pidKi * pidIntegral

        // Rate-limit how fast the output can move each tick:
        // - Early settling: no increases allowed (athlete still warming up)
        // - Normal: increase slowly, decrease faster for safety
        let dt = Constants.sampleInterval
        let maxIncrease = inEarlyPhase ? 0.0 : pidMaxRateIncrease * dt
        let maxDecrease = pidMaxRateDecrease * dt

        let delta = rawOutput - pidOutputWatts
        let clampedDelta = max(-maxDecrease, min(maxIncrease, delta))
        pidOutputWatts += clampedDelta
        pidOutputWatts = max(Double(-maxDriftFromTarget), min(Double(maxDriftFromTarget), pidOutputWatts))

        let newPower = max(50, workout.targetPower + Int(pidOutputWatts.rounded()))
        if newPower != adjustedPower {
            adjustedPower = newPower
            kickrService.setTargetPower(adjustedPower)
        }
    }

    // MARK: - Manual Power Adjustment

    func incrementPower() {
        adjustedPower = min(adjustedPower + 5, workout.targetPower + maxDriftFromTarget)
        kickrService.setTargetPower(adjustedPower)
        // Sync PID so it doesn't immediately fight the manual change
        pidOutputWatts = Double(adjustedPower - workout.targetPower)
        pidIntegral = 0
    }

    func decrementPower() {
        adjustedPower = max(adjustedPower - 5, max(workout.targetPower - maxDriftFromTarget, 50))
        kickrService.setTargetPower(adjustedPower)
        pidOutputWatts = Double(adjustedPower - workout.targetPower)
        pidIntegral = 0
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
