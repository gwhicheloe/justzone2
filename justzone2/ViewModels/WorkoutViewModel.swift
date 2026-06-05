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
    @Published var hrSource: HRSource
    /// Computed shorthand kept so read sites don't all need to migrate at once.
    var useWatchHR: Bool { hrSource == .appleWatch }
    @Published var isSwitchingHRSource = false
    @Published var hrSourceError: String?
    @Published var showHRStrapPicker = false
    /// Mirrors watchConnectivityService.hasReceivedHR so SwiftUI reactively
    /// re-renders banners/alerts that depend on Watch HR delivery state.
    @Published private(set) var hasWatchHR: Bool = false
    /// Mirrors healthKitManager.hasReceivedBuilderHR for the AirPods path.
    @Published private(set) var hasNativeHR: Bool = false

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
    private let zone2Min: Int
    private let zone2Max: Int
    /// Public read-only accessors for the active Zone 2 range (e.g. for the
    /// Strava description). The private versions drive the PID.
    var zone2MinValue: Int { zone2Min }
    var zone2MaxValue: Int { zone2Max }
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

    // HR gradient — scale power increases while HR is still rising
    private var heavySmoothHR: Double = 0          // 300 s EMA of raw HR
    private let hrGradientSaturation: Double = 2.0 // bpm/min at which increases fully suppressed

    private var timerCancellable: AnyCancellable?
    private var hrCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var watchLaunchTask: Task<Void, Never>?
    /// A cold `startWatchApp` wake can take ~45–60 s to launch the Watch app,
    /// start its HKWorkoutSession, and bring up the WCSession channel. Wait out
    /// that window before surfacing the "no HR" alert.
    private static let watchColdStartTimeout: TimeInterval = 45
    private var workoutStartTime: Date?
    private var powerBuffer: [Int] = []
    private let powerSmoothingWindow = 5
    private var accumulatedDistance: Double = 0

    // Checkpoint persistence
    private let checkpointInterval: TimeInterval = 300  // 5 minutes
    private var lastCheckpointAt: TimeInterval = 0

    /// Whether the Watch is currently sending HR samples for this workout.
    /// True once at least one HR sample has arrived via WCSession.
    var isWatchConnected: Bool {
        useWatchHR && hasWatchHR
    }

    init(
        workout: Workout,
        bluetoothManager: BluetoothManager,
        kickrService: KickrService,
        heartRateService: HeartRateService,
        healthKitManager: HealthKitManager,
        liveActivityManager: LiveActivityManager,
        watchConnectivityService: WatchConnectivityService,
        hrSource: HRSource = .bleStrap,
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
        self.hrSource = hrSource
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

        // Mirror Watch HR delivery state into a @Published on this VM so
        // SwiftUI views that depend on it (Connecting banner, alert content)
        // re-render when it flips.
        watchConnectivityService.$hasReceivedHR
            .assign(to: &$hasWatchHR)

        // Same for the AirPods (native HKLiveWorkoutBuilder HR) path.
        healthKitManager.$hasReceivedBuilderHR
            .assign(to: &$hasNativeHR)

        // Surface Watch-side session-start failures (e.g. app backgrounded) as
        // an HR-source error and abort any pending launch retry.
        watchConnectivityService.$watchStartError
            .compactMap { $0 }
            .sink { [weak self] message in
                guard let self = self, self.useWatchHR else { return }
                self.watchLaunchTask?.cancel()
                self.watchLaunchTask = nil
                self.hrSourceError = message
                self.watchConnectivityService.watchStartError = nil
            }
            .store(in: &cancellables)
    }

    private func bindHRSource() {
        hrCancellable?.cancel()
        switch hrSource {
        case .appleWatch:
            // Watch streams HR over WCSession.
            hrCancellable = watchConnectivityService.$fallbackHeartRate
                .sink { [weak self] hr in self?.currentHeartRate = hr }
        case .airPods:
            // AirPods Pro 3 in-ear PPG → HealthKit store → iPhone's
            // HKLiveWorkoutBuilder auto-collects → didCollectDataOf delegate
            // publishes builderHeartRate. We just subscribe to it.
            hrCancellable = healthKitManager.$builderHeartRate
                .sink { [weak self] hr in self?.currentHeartRate = hr }
        case .bleStrap:
            hrCancellable = heartRateService.$currentHeartRate
                .sink { [weak self] hr in self?.currentHeartRate = hr }
        }
    }

    /// Whether the chosen HR source is currently producing samples.
    /// Drives the "Connecting to X…" banner in WorkoutView.
    var isHRSourceConnected: Bool {
        switch hrSource {
        case .appleWatch: return hasWatchHR
        case .airPods:    return hasNativeHR
        case .bleStrap:   return heartRateService.isConnected
        }
    }

    // MARK: - HR Source Switching

    func switchToWatchHR() {
        guard !isSwitchingHRSource else { return }
        guard state == .running || state == .paused else { return }
        dlog("[IPHONE-VM] switchToWatchHR — hrSource → appleWatch")

        isSwitchingHRSource = true
        hrSourceError = nil

        Task {
            // The iPhone HK session keeps running across the switch — it's the
            // record sink either way. We just change the HR feed source.
            // Detach any live data source first: if we were on AirPods it has
            // iOS pulling HR from the Watch, which would block our Watch app's
            // own session from starting.
            healthKitManager.detachLiveHRCollection()
            hrSource = .appleWatch
            bindHRSource()
            watchConnectivityService.resetHRStats()
            launchWatchWorkout()

            isSwitchingHRSource = false
        }
    }

    func switchToBLEHR() {
        guard !isSwitchingHRSource else { return }
        guard state == .running || state == .paused else { return }
        dlog("[IPHONE-VM] switchToBLEHR — strapConnected=\(heartRateService.isConnected)")

        if heartRateService.isConnected {
            completeSwitchToBLE()
        } else {
            startHRStrapSelection()
        }
    }

    func switchToAirPods() {
        guard !isSwitchingHRSource else { return }
        guard state == .running || state == .paused else { return }
        dlog("[IPHONE-VM] switchToAirPods — hrSource → airPods")

        isSwitchingHRSource = true
        hrSourceError = nil

        // If we're leaving the Watch source, tell the Watch to stop its session.
        if hrSource == .appleWatch {
            watchConnectivityService.sendStopWorkout()
        }
        healthKitManager.resetBuilderHRStats()
        // The session may have started without a live data source (Watch/BLE
        // start). AirPods needs it, so attach now if it isn't already.
        healthKitManager.attachLiveHRCollection()
        hrSource = .airPods
        bindHRSource()
        isSwitchingHRSource = false
    }

    func startHRStrapSelection() {
        guard state == .running || state == .paused else { return }
        dlog("[IPHONE-VM] startHRStrapSelection — opening picker")
        bluetoothManager.startScanning()
        showHRStrapPicker = true
    }

    func selectAndConnectHRStrap(_ device: DeviceInfo) {
        guard !isSwitchingHRSource else { return }
        dlog("[IPHONE-VM] selectAndConnectHRStrap — device=\(device.name)")

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
        dlog("[IPHONE-VM] retryWatchConnection — user tapped Retry")
        launchWatchWorkout()
    }

    private func completeSwitchToBLE() {
        dlog("[IPHONE-VM] completeSwitchToBLE — hrSource → bleStrap")
        isSwitchingHRSource = true
        hrSourceError = nil

        // Stop the Watch session — we don't need its HR anymore.
        watchConnectivityService.sendStopWorkout()
        // iPhone HK session continues — same record sink.
        hrSource = .bleStrap
        bindHRSource()
        isSwitchingHRSource = false
    }

    // MARK: - Workout Lifecycle

    func startWorkout() {
        guard state == .idle else { return }

        UIApplication.shared.isIdleTimerDisabled = true
        watchConnectivityService.resetHRStats()
        healthKitManager.resetBuilderHRStats()

        let startPower = warmUpEnabled ? workout.targetPower / 2 : workout.targetPower
        kickrService.setTargetPower(startPower)
        kickrService.startWorkout()

        // iPhone always owns the workout record now — start the HK session
        // regardless of HR source. HR samples flow into this builder via
        // addHeartRateSample, sourced from Watch (Mode A) or BLE (Mode B).
        // Only AirPods needs the live data source; attaching it for the Watch
        // source makes iOS commandeer the Watch for HR and blocks our Watch app.
        Task {
            do {
                try await healthKitManager.startWorkoutSession(collectLiveHR: hrSource.writesToBuilderNatively)
            } catch {
                dlog("[IPHONE-VM] startWorkoutSession FAILED: \(error.localizedDescription)")
            }
        }

        if useWatchHR {
            launchWatchWorkout()
        } else {
            // Launch Watch in display-only mode so it stays alive in background
            // for update delivery. Falls back to WCSession message if startWatchApp fails.
            Task {
                do {
                    try await healthKitManager.startWatchDisplayApp()
                } catch {
                    dlog("[IPHONE-VM] startWatchDisplayApp FAILED, falling back to WCSession: \(error.localizedDescription)")
                    watchConnectivityService.sendStartDisplayWorkout()
                }
            }
        }

        do {
            try liveActivityManager.startLiveActivity(
                targetPower: workout.targetPower,
                targetDuration: workout.targetDuration
            )
        } catch {
            dlog("[IPHONE-VM] startLiveActivity FAILED: \(error.localizedDescription)")
        }

        workoutStartTime = Date()
        accumulatedDistance = 0
        state = .running

        saveCheckpoint(status: .inProgress)
        lastCheckpointAt = 0

        startTimer()
    }

    /// Resume a workout after iOS killed and relaunched the app.
    /// Repopulates samples and starts a fresh iPhone HK session for continued recording.
    func resumeRecoveredWorkout(elapsedTime: TimeInterval) {
        guard state == .idle else { return }

        UIApplication.shared.isIdleTimerDisabled = true

        self.elapsedTime = elapsedTime
        workoutStartTime = Date() - elapsedTime
        accumulatedDistance = workout.samples.last?.distance ?? 0

        // Repopulate chart from any persisted samples so the chart shows the recovered history
        chartData = workout.samples.map { sample in
            ChartDataPoint(time: sample.timestamp, heartRate: sample.heartRate, power: sample.power)
        }

        // If warm-up already passed, mark it complete
        if warmUpEnabled && elapsedTime >= warmUpDuration {
            warmUpComplete = true
        }

        let resumePower = warmUpEnabled && !warmUpComplete ? workout.targetPower / 2 : adjustedPower
        kickrService.setTargetPower(resumePower)
        kickrService.startWorkout()

        // Start a fresh iPhone HK session for the recovered workout.
        Task {
            do {
                try await healthKitManager.startWorkoutSession(collectLiveHR: hrSource.writesToBuilderNatively)
            } catch {
                dlog("[IPHONE-VM] startWorkoutSession (recovery) FAILED: \(error.localizedDescription)")
            }
        }
        if useWatchHR {
            launchWatchWorkout()
        }

        do {
            try liveActivityManager.startLiveActivity(
                targetPower: workout.targetPower,
                targetDuration: workout.targetDuration
            )
        } catch {
            dlog("[IPHONE-VM] startLiveActivity (recovery) FAILED: \(error.localizedDescription)")
        }

        state = .running

        saveCheckpoint(status: .inProgress)
        lastCheckpointAt = elapsedTime

        startTimer()
    }

    /// Launch the Watch app via HealthKit (the only way to wake it from
    /// iPhone) and send a WCSession backup so the Watch starts its session
    /// even if the HK launch handler doesn't fire promptly. Watch then sends
    /// HR back via WCSession; the iPhone will see hasReceivedHR flip true.
    /// Cancelled early if the Watch reports a session-start error.
    ///
    /// Waits out the cold-start window (`watchColdStartTimeout`), polling for
    /// the first HR sample. We deliberately issue `startWatchApp` only once: a
    /// second wake mid-launch can reset the Watch's in-progress launch and push
    /// first-HR even later. The queued `transferUserInfo` backup guarantees the
    /// start command reaches the Watch even while it's unreachable. If still no
    /// HR by the deadline, surfaces an alert with Retry / Use HR Strap options
    /// via `hrSourceError` (the user's Retry then triggers a fresh launch).
    private func launchWatchWorkout() {
        watchLaunchTask?.cancel()
        watchConnectivityService.markWatchLaunch()
        watchLaunchTask = Task {
            await tryStartWatch()

            // Poll for the first HR sample across the cold-start window rather
            // than re-launching — a cold Watch app can take ~45–60 s to deliver.
            let deadline = Date().addingTimeInterval(Self.watchColdStartTimeout)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                if watchConnectivityService.hasReceivedHR {
                    dlog("[IPHONE-VM] launchWatchWorkout — HR arrived")
                    return
                }
            }

            dlog("[IPHONE-VM] WATCH_HR_TIMEOUT_FINAL — no HR within \(Int(Self.watchColdStartTimeout))s, surfacing alert")
            hrSourceError = "Apple Watch isn't sending heart rate. Tap Retry, or switch to your HR strap."
        }
    }

    /// One launch: HKHealthStore.startWatchApp(.indoor) + WCSession backup.
    private func tryStartWatch() async {
        dlog("[IPHONE-VM] launchWatchWorkout — startWatchApp + WCSession backup")
        do {
            try await healthKitManager.startWatchWorkout()
            dlog("[IPHONE-VM] startWatchWorkout returned OK")
        } catch {
            dlog("[IPHONE-VM] startWatchWorkout FAILED: \(error.localizedDescription)")
        }
        if Task.isCancelled {
            dlog("[IPHONE-VM] launchWatchWorkout cancelled — Watch reported error")
            return
        }
        watchConnectivityService.sendStartWorkout()
        dlog("[IPHONE-VM] sendStartWorkout (WCSession backup) sent")
    }

    func pauseWorkout() {
        guard state == .running else { return }

        timerCancellable?.cancel()
        timerCancellable = nil
        state = .paused

        kickrService.stopWorkout()
        healthKitManager.pauseWorkoutSession()
        watchConnectivityService.sendPauseWorkout()
        sendWatchDisplayUpdate(state: "paused")

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

        healthKitManager.resumeWorkoutSession()
        watchConnectivityService.sendResumeWorkout()
        sendWatchDisplayUpdate(state: "running")

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
        endIPhoneSessionAndNotifyWatch()

        saveCheckpoint(status: .pendingUpload)
        liveActivityManager.endLiveActivity()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func startCooldown() {
        timerCancellable?.cancel()
        timerCancellable = nil

        workout.finish()

        // Leave KICKR running at half power so rider can cool down while viewing summary
        kickrService.setTargetPower(workout.targetPower / 2)

        endIPhoneSessionAndNotifyWatch()

        saveCheckpoint(status: .pendingUpload)
        liveActivityManager.endLiveActivity()
        UIApplication.shared.isIdleTimerDisabled = false

        state = .completed
    }

    /// End the iPhone HealthKit session (saves the workout to Health) and tell
    /// the Watch to stop its session too. Same teardown for both modes.
    private func endIPhoneSessionAndNotifyWatch() {
        Task {
            do {
                healthKitWorkout = try await healthKitManager.endWorkoutSession()
            } catch {
                dlog("[IPHONE-VM] endWorkoutSession FAILED: \(error.localizedDescription)")
            }
        }
        if useWatchHR {
            watchConnectivityService.sendStopWorkout()
        } else {
            watchConnectivityService.sendWorkoutEnded()
        }
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
        let cad = kickrService.currentCadence > 0 ? kickrService.currentCadence : nil
        let speed = virtualSpeed(watts: currentPower)
        accumulatedDistance += speed * Constants.sampleInterval

        workout.addSample(heartRate: hr, power: pwr, cadence: cad, speed: speed > 0 ? speed : nil, distance: accumulatedDistance)
        evaluateZoneTargeting()

        // iPhone owns the HK record. HR samples need a manual write only when
        // the source doesn't already feed the builder — Watch (WCSession) and
        // BLE strap. AirPods writes natively via HKLiveWorkoutDataSource, so
        // a manual add would duplicate the sample.
        if let heartRate = hr, !hrSource.writesToBuilderNatively {
            healthKitManager.addHeartRateSample(heartRate, at: now)
        }
        if let power = pwr {
            healthKitManager.addPowerSample(power, at: now)
        }
        sendWatchDisplayUpdate(state: "running")

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

        if elapsedTime - lastCheckpointAt >= checkpointInterval {
            saveCheckpoint(status: .inProgress)
            lastCheckpointAt = elapsedTime
        }

        if elapsedTime >= workout.targetDuration {
            startCooldown()
        }
    }

    /// Persist the current workout (with samples) to disk. Used for periodic
    /// checkpoints and final save on completion. Status determines whether
    /// the workout is still recoverable (.inProgress) or awaiting Strava
    /// upload (.pendingUpload).
    private func saveCheckpoint(status: LocalWorkout.Status) {
        let local = LocalWorkout(
            workout: workout,
            useWatchHR: useWatchHR,
            zoneTargetingEnabled: zoneTargetingEnabled,
            warmUpEnabled: warmUpEnabled,
            elapsedTime: elapsedTime,
            status: status,
            lastCheckpoint: Date(),
            hrSourceName: hrSource.displayName,
            zone2Min: zone2Min,
            zone2Max: zone2Max
        )
        LocalWorkoutStore.shared.save(local)
    }

    // MARK: - Watch Data

    /// Virtual speed (m/s) from power using standard cycling aerodynamic model on flat road.
    /// P = 0.5·CdA·ρ·v³ + Crr·m·g·v  — solved with Newton-Raphson.
    /// CdA=0.5 matches a typical road cyclist on the hoods (~17 mph at 168W).
    private func virtualSpeed(watts: Int) -> Double {
        let P = Double(max(watts, 0))
        guard P > 0 else { return 0 }
        let a = 0.5 * 0.5 * 1.225          // 0.5·CdA·ρ, CdA=0.5 m² (hoods position)
        let b = 0.004 * 80.0 * 9.81         // Crr·m·g (rolling resistance)
        var v = 6.0  // initial guess (~22 km/h)
        for _ in 0..<20 {
            let fv = a * v * v * v + b * v - P
            let dfv = 3.0 * a * v * v + b
            v -= fv / dfv
            if v < 0 { v = 0.1 }
        }
        return v
    }

    /// Send display data (HR, power, elapsed, state) to Watch over WCSession.
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
        heavySmoothHR = 0
    }

    private func evaluateZoneTargeting() {
        guard zoneTargetingEnabled else { return }
        guard currentHeartRate > 0 else { return }

        // Always update buffers so history is ready when PID engages
        hrBuffer.append(currentHeartRate)
        if hrBuffer.count > hrBufferSize {
            hrBuffer.removeFirst(hrBuffer.count - hrBufferSize)
        }

        // Heavy-smoothed HR (τ = 300 s EMA) — tick-to-tick derivative gives a
        // stable gradient without needing a separate history buffer
        let emaAlpha = Constants.sampleInterval / 300.0
        let prevSmoothHR = heavySmoothHR
        heavySmoothHR = heavySmoothHR > 0
            ? emaAlpha * Double(currentHeartRate) + (1 - emaAlpha) * heavySmoothHR
            : Double(currentHeartRate)

        // Grace period — let HR settle before PID engages
        guard elapsedTime >= warmUpGracePeriod else { return }
        guard hrBuffer.count >= hrBufferSize else { return }

        let smoothedHR = Double(hrBuffer.reduce(0, +)) / Double(hrBuffer.count)
        let setpoint = Double(zone2Min + zone2Max) / 2.0

        // error > 0  → HR below zone → need more power
        // error < 0  → HR above zone → need less power
        let error = setpoint - smoothedHR

        // Gradient of the slow EMA (bpm/min). Scale integral accumulation and
        // max increase rate proportionally — smooth back-off with no extra state.
        let hrGradient = prevSmoothHR > 0
            ? (heavySmoothHR - prevSmoothHR) / Constants.sampleInterval * 60.0
            : 0.0
        let gradientFactor = max(0.0, min(1.0, 1.0 - hrGradient / hrGradientSaturation))

        pidIntegral += gradientFactor * error * Constants.sampleInterval
        let maxIntegral = Double(maxDriftFromTarget) / max(pidKi, 0.001)
        pidIntegral = max(-maxIntegral, min(maxIntegral, pidIntegral))

        let rawOutput = pidKp * error + pidKi * pidIntegral

        let dt = Constants.sampleInterval
        let maxIncrease = gradientFactor * pidMaxRateIncrease * dt
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
