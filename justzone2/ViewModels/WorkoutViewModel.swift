import SwiftUI
import Combine

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

    let kickrService: KickrService
    let heartRateService: HeartRateService

    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var workoutStartTime: Date?

    init(workout: Workout, kickrService: KickrService, heartRateService: HeartRateService) {
        self.workout = workout
        self.kickrService = kickrService
        self.heartRateService = heartRateService

        setupBindings()
    }

    private func setupBindings() {
        // Subscribe to HR updates
        heartRateService.$currentHeartRate
            .assign(to: &$currentHeartRate)

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
    }

    func resumeWorkout() {
        guard state == .paused else { return }

        kickrService.startWorkout()
        kickrService.setTargetPower(workout.targetPower)
        state = .running

        startTimer()
    }

    func stopWorkout() {
        timerCancellable?.cancel()
        timerCancellable = nil

        workout.finish()
        state = .completed

        kickrService.stopWorkout()

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

        // Update elapsed time
        if let startTime = workoutStartTime {
            elapsedTime = Date().timeIntervalSince(startTime)
        }

        // Record sample
        let hr = currentHeartRate > 0 ? currentHeartRate : nil
        let pwr = currentPower > 0 ? currentPower : nil

        workout.addSample(heartRate: hr, power: pwr)

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
