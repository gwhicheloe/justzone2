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

    let kickrService: KickrService
    let heartRateService: HeartRateService
    let healthKitManager: HealthKitManager
    let liveActivityManager: LiveActivityManager
    let watchConnectivityService: WatchConnectivityService
    let useWatchHR: Bool

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
    private var cancellables = Set<AnyCancellable>()
    private var workoutStartTime: Date?

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
        // Subscribe to HR updates - from Watch or Bluetooth
        if useWatchHR {
            watchConnectivityService.$watchHeartRate
                .assign(to: &$currentHeartRate)
        } else {
            heartRateService.$currentHeartRate
                .assign(to: &$currentHeartRate)
        }

        // Subscribe to power updates
        kickrService.$currentPower
            .assign(to: &$currentPower)
    }

    func startWorkout() {
        guard state == .idle else { return }

        // Keep screen awake
        UIApplication.shared.isIdleTimerDisabled = true

        // Set target power and start ERG mode (works asynchronously)
        kickrService.setTargetPower(workout.targetPower)
        kickrService.startWorkout()

        // Start HealthKit workout session for background execution
        Task {
            do {
                try await healthKitManager.startWorkoutSession()
            } catch {
                print("Failed to start HealthKit session: \(error.localizedDescription)")
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

        // Start Watch HR sampling if using Watch as HR source
        if useWatchHR {
            watchConnectivityService.sendStartHRSampling()
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

        // Pause HealthKit session
        healthKitManager.pauseWorkoutSession()

        // Update Live Activity to show paused state
        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: true
        )

        // Notify Watch
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

    func resumeWorkout() {
        guard state == .paused else { return }

        kickrService.startWorkout()
        kickrService.setTargetPower(adjustedPower)
        lastAdjustmentTime = Date()
        state = .running

        // Resume HealthKit session
        healthKitManager.resumeWorkoutSession()

        // Update Live Activity to show running state
        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: false
        )

        // Notify Watch
        watchConnectivityService.sendWorkoutUpdate(
            heartRate: currentHeartRate,
            power: currentPower,
            elapsedTime: elapsedTime,
            chunkRemaining: timeRemainingInChunk,
            currentChunk: currentChunk,
            totalChunks: totalChunks,
            state: "running"
        )

        startTimer()
    }

    func stopWorkout() {
        timerCancellable?.cancel()
        timerCancellable = nil

        workout.finish()
        state = .completed

        kickrService.stopWorkout()

        // End HealthKit session and save workout
        Task {
            do {
                healthKitWorkout = try await healthKitManager.endWorkoutSession()
            } catch {
                print("Failed to end HealthKit session: \(error.localizedDescription)")
            }
        }

        // End Live Activity
        liveActivityManager.endLiveActivity()

        // Stop Watch HR sampling and notify workout ended
        if useWatchHR {
            watchConnectivityService.sendStopHRSampling()
        }
        watchConnectivityService.sendWorkoutEnded()

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

        // Add samples to HealthKit
        if let heartRate = hr {
            healthKitManager.addHeartRateSample(heartRate, at: now)
        }
        if let power = pwr {
            healthKitManager.addPowerSample(power, at: now)
        }

        // Update Live Activity
        liveActivityManager.updateLiveActivity(
            elapsedTime: elapsedTime,
            heartRate: currentHeartRate,
            power: currentPower,
            isPaused: false
        )

        // Update Watch companion display
        watchConnectivityService.sendWorkoutUpdate(
            heartRate: currentHeartRate,
            power: currentPower,
            elapsedTime: elapsedTime,
            chunkRemaining: timeRemainingInChunk,
            currentChunk: currentChunk,
            totalChunks: totalChunks,
            state: "running"
        )

        // Add to chart data
        chartData.append(ChartDataPoint(
            time: elapsedTime,
            heartRate: hr,
            power: pwr
        ))

        // Check if target duration reached
        if elapsedTime >= workout.targetDuration {
            stopWorkout()
        }
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
