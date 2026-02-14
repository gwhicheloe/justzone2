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
    @Published var watchDisconnected = false
    @Published var isSwitchingHRSource = false
    @Published var hrSourceError: String?

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

    init(
        workout: Workout,
        kickrService: KickrService,
        heartRateService: HeartRateService,
        healthKitManager: HealthKitManager,
        liveActivityManager: LiveActivityManager,
        watchConnectivityService: WatchConnectivityService,
        useWatchHR: Bool = false,
        zoneTargetingEnabled: Bool = false
    ) {
        self.workout = workout
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
        // Initial HR binding
        bindHRSource()

        // Subscribe to power updates
        kickrService.$currentPower
            .assign(to: &$currentPower)

        // Monitor Watch disconnection
        healthKitManager.$mirroredSessionDisconnected
            .assign(to: &$watchDisconnected)
    }

    private func bindHRSource() {
        hrCancellable?.cancel()
        if useWatchHR {
            // Mode A: HR flows through mirrored HKWorkoutSession
            hrCancellable = healthKitManager.$mirroredHeartRate
                .sink { [weak self] hr in self?.currentHeartRate = hr }
        } else {
            // Mode B: HR from Bluetooth HR monitor
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
            // End standalone HK session
            _ = try? await healthKitManager.endWorkoutSession()

            // Launch Watch workout
            do {
                try await healthKitManager.startWatchWorkout()
            } catch {
                print("Switch to Watch: failed to launch Watch app: \(error.localizedDescription)")
            }
            // Backup via WCSession
            watchConnectivityService.sendStartWorkout()

            // Wait for mirrored session (up to 5 seconds)
            let deadline = Date().addingTimeInterval(5)
            while !healthKitManager.isMirrored && Date() < deadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            if healthKitManager.isMirrored {
                // Success
                useWatchHR = true
                bindHRSource()
                sendDataToWatch(state: state == .paused ? "paused" : "running")
            } else {
                // Timeout — revert to standalone
                do {
                    try await healthKitManager.startWorkoutSession()
                } catch {
                    print("Switch to Watch: failed to restart standalone: \(error.localizedDescription)")
                }
                hrSourceError = "Watch did not respond — keeping HR strap"
            }

            isSwitchingHRSource = false
        }
    }

    func switchToBLEHR() {
        guard !isSwitchingHRSource else { return }
        guard state == .running || state == .paused else { return }

        isSwitchingHRSource = true
        hrSourceError = nil

        Task {
            // Tell Watch to end its primary session
            sendDataToWatch(state: "ended")
            watchConnectivityService.sendStopWorkout()

            // Clean up mirrored session
            healthKitManager.endMirroredSession()

            // Start standalone session
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

        // Keep screen awake
        UIApplication.shared.isIdleTimerDisabled = true

        // Set target power and start ERG mode (works asynchronously)
        kickrService.setTargetPower(workout.targetPower)
        kickrService.startWorkout()

        if useWatchHR {
            // Mode A: Launch Watch app to start primary session with mirroring
            Task {
                do {
                    try await healthKitManager.startWatchWorkout()
                } catch {
                    print("Failed to start Watch workout: \(error.localizedDescription)")
                }
            }
            // Backup: send start command via WCSession in case startWatchApp doesn't trigger
            watchConnectivityService.sendStartWorkout()
        } else {
            // Mode B: Start standalone HealthKit session on iPhone
            Task {
                do {
                    try await healthKitManager.startWorkoutSession()
                } catch {
                    print("Failed to start HealthKit session: \(error.localizedDescription)")
                }
            }
        }

        // Start Live Activity for lock screen visibility
        do {
            try liveActivityManager.startLiveActivity(
                targetPower: workout.targetPower,
                targetDuration: workout.targetDuration
            )
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }

        // Start workout immediately - ERG will engage in background
        workoutStartTime = Date()
        state = .running

        // Start sampling timer
        startTimer()
    }

    func pauseWorkout() {
        guard state == .running else { return }

        timerCancellable?.cancel()
        timerCancellable = nil
        state = .paused

        kickrService.stopWorkout()

        if useWatchHR {
            // Mode A: Send pause state via mirrored session data channel
            sendDataToWatch(state: "paused")
            // Backup via WCSession
            watchConnectivityService.sendPauseWorkout()
        } else {
            // Mode B: Pause standalone session directly
            healthKitManager.pauseWorkoutSession()
            // Notify Watch display
            watchConnectivityService.sendWorkoutUpdate(
                heartRate: currentHeartRate,
                power: currentPower,
                elapsedTime: elapsedTime,
                chunkRemaining: timeRemainingInChunk,
                currentChunk: currentChunk,
                totalChunks: totalChunks,
                state: "paused"
            )
        }

        // Update Live Activity to show paused state
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
            // Mode A: Send resume state via mirrored session data channel
            sendDataToWatch(state: "running")
            // Backup via WCSession
            watchConnectivityService.sendResumeWorkout()
        } else {
            // Mode B: Resume standalone session directly
            healthKitManager.resumeWorkoutSession()
            // Notify Watch display
            watchConnectivityService.sendWorkoutUpdate(
                heartRate: currentHeartRate,
                power: currentPower,
                elapsedTime: elapsedTime,
                chunkRemaining: timeRemainingInChunk,
                currentChunk: currentChunk,
                totalChunks: totalChunks,
                state: "running"
            )
        }

        // Update Live Activity to show running state
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
            // Mode A: Tell Watch to end its primary session (saves workout to Health)
            sendDataToWatch(state: "ended")
            // Backup via WCSession
            watchConnectivityService.sendStopWorkout()
            // Clean up mirrored session on iPhone side
            healthKitManager.endMirroredSession()
        } else {
            // Mode B: End standalone session and save workout
            Task {
                do {
                    healthKitWorkout = try await healthKitManager.endWorkoutSession()
                } catch {
                    print("Failed to end HealthKit session: \(error.localizedDescription)")
                }
            }
            // Notify Watch display
            watchConnectivityService.sendWorkoutEnded()
        }

        // End Live Activity
        liveActivityManager.endLiveActivity()

        // Allow screen to sleep again
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

        // Update elapsed time
        if let startTime = workoutStartTime {
            elapsedTime = now.timeIntervalSince(startTime)
        }

        // Record sample
        let hr = currentHeartRate > 0 ? currentHeartRate : nil
        let pwr = currentPower > 0 ? currentPower : nil

        workout.addSample(heartRate: hr, power: pwr)

        // Zone targeting: auto-adjust power based on HR
        evaluateZoneTargeting()

        if useWatchHR {
            // Mode A: Send power/chunk data to Watch via mirrored session
            sendDataToWatch(state: "running")
            // Add power to mirrored builder (Watch handles HR)
            if let power = pwr {
                healthKitManager.addPowerToMirroredBuilder(power, at: now)
            }
        } else {
            // Mode B: Add samples to standalone HealthKit session
            if let heartRate = hr {
                healthKitManager.addHeartRateSample(heartRate, at: now)
            }
            if let power = pwr {
                healthKitManager.addPowerSample(power, at: now)
            }
            // Update Watch companion display via WCSession
            watchConnectivityService.sendWorkoutUpdate(
                heartRate: currentHeartRate,
                power: currentPower,
                elapsedTime: elapsedTime,
                chunkRemaining: timeRemainingInChunk,
                currentChunk: currentChunk,
                totalChunks: totalChunks,
                state: "running"
            )
        }

        // Update Live Activity
        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: false
        )

        // Add to chart data with smoothed power
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

        // Check if target duration reached
        if elapsedTime >= workout.targetDuration {
            stopWorkout()
        }
    }

    // MARK: - Mode A: Send Data to Watch

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

    var progress: Double {
        guard workout.targetDuration > 0 else { return 0 }
        return min(elapsedTime / workout.targetDuration, 1.0)
    }

    var remainingTime: TimeInterval {
        max(workout.targetDuration - elapsedTime, 0)
    }

    // MARK: - Chunk-based timing (10-minute chunks)

    var chunkDuration: TimeInterval { 10 * 60 } // 10 minutes

    var currentChunk: Int {
        min(Int(elapsedTime / chunkDuration) + 1, totalChunks)
    }

    var totalChunks: Int {
        max(1, Int(ceil(workout.targetDuration / chunkDuration)))
    }

    var timeRemainingInChunk: TimeInterval {
        // For the last chunk, use actual remaining time
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

        // Always update the rolling HR buffer (even during warm-up)
        hrBuffer.append(currentHeartRate)
        if hrBuffer.count > hrBufferSize {
            hrBuffer.removeFirst(hrBuffer.count - hrBufferSize)
        }

        // Don't make adjustments during warm-up
        guard elapsedTime >= warmUpGracePeriod else { return }

        // Need a full buffer before making decisions
        guard hrBuffer.count >= hrBufferSize else { return }

        // Compute smoothed HR (30-second rolling average)
        let smoothedHR = hrBuffer.reduce(0, +) / hrBuffer.count

        // Dead band — if smoothed HR is within zone, do nothing
        if smoothedHR >= zone2Min && smoothedHR <= zone2Max {
            return
        }

        // Cooldown — check if enough time has elapsed since last adjustment
        let now = Date()
        if let lastAdj = lastAdjustmentTime {
            let requiredCooldown = lastAdjustmentWasDecrease
                ? cooldownAfterDecrease
                : cooldownAfterIncrease
            guard now.timeIntervalSince(lastAdj) >= requiredCooldown else { return }
        }

        // Determine direction of adjustment
        var newPower = adjustedPower

        if smoothedHR > zone2Max {
            newPower -= powerStepSize
            lastAdjustmentWasDecrease = true
        } else if smoothedHR < zone2Min {
            newPower += powerStepSize
            lastAdjustmentWasDecrease = false
        }

        // Clamp to max drift range and minimum
        let lowerBound = workout.targetPower - maxDriftFromTarget
        let upperBound = workout.targetPower + maxDriftFromTarget
        newPower = max(max(lowerBound, 50), min(upperBound, newPower))

        // Apply if changed
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
