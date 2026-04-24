import WatchConnectivity
import HealthKit

@MainActor
class WatchSessionManager: NSObject, ObservableObject {
    @Published var heartRate: Int = 0
    @Published var power: Int = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var chunkRemaining: TimeInterval = 0
    @Published var currentChunk: Int = 0
    @Published var totalChunks: Int = 0
    @Published var workoutState: String = "idle"
    @Published var isPhoneReachable = false
    @Published var hrPermissionDenied = false

    private var wcSession: WCSession?
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// True only when startMirroringToCompanionDevice() has succeeded and the channel is live.
    /// Used to decide whether WCSession display updates should be accepted as fallback.
    private var mirroringEstablished = false
    private var lastMirroringRetryAt: Date?

    /// Prevents duplicate session starts when both mirroring handler and WCSession backup fire simultaneously.
    private var isStartingWorkout = false

    /// One-shot flag to log WCSession HR fallback activation once per workout.
    private var loggedWCSessionFallback = false

    /// Counter for WCSession workoutUpdate messages — only log first and every 30th to reduce spam.
    private var wcUpdateCount = 0

    /// Direct HealthKit HR observation query — reads HR from system sensor data.
    /// Bypasses HKLiveWorkoutDataSource which requires write authorization.
    private var hrQuery: HKAnchoredObjectQuery?

    // MARK: - Watch-side log (sent to iPhone at workout end)

    /// Thread-safe log store — held as a `let` so nonisolated methods can access it safely.
    nonisolated(unsafe) private let watchLog = WatchLogStore()

    /// Callable from any isolation context (nonisolated delegates, completion handlers, etc.)
    nonisolated func wlog(_ message: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        let entry = "[\(f.string(from: Date()))] \(message)"
        print(entry)
        watchLog.append(entry)
    }

    private func sendLogToPhone() {
        let logText = watchLog.flush()
        guard !logText.isEmpty else { return }
        wcSession?.transferUserInfo(["type": "watchLog", "log": logText])
        wlog("[WATCH] log flushed and sent to iPhone")
    }

    override init() {
        super.init()

        // Set up WCSession for receiving start/stop commands and Mode B display updates
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }

        // Handle launch from iPhone via startWatchApp(with:)
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            let locationType = mirroredSession.workoutConfiguration.locationType.rawValue
            self?.wlog("[WATCH] workoutSessionMirroringStartHandler fired — locationType raw=\(locationType)")
            Task { @MainActor in
                await self?.handleStartFromPhone(session: mirroredSession)
            }
        }
    }

    // MARK: - HealthKit Authorization

    func requestAuthorization() async {
        wlog("[WATCH] requestAuthorization called")
        let hrType = HKQuantityType(.heartRate)
        let typesToRead: Set<HKObjectType> = [hrType]
        let typesToWrite: Set<HKSampleType> = [HKWorkoutType.workoutType(), hrType]
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            let hrWriteStatus = healthStore.authorizationStatus(for: hrType)
            // 0=notDetermined, 1=sharingDenied, 2=sharingAuthorized
            wlog("[WATCH] requestAuthorization completed — HR write status: \(hrWriteStatus.rawValue)")
            hrPermissionDenied = hrWriteStatus != .sharingAuthorized
        } catch {
            wlog("[WATCH] requestAuthorization FAILED: \(error.localizedDescription)")
        }
    }

    // MARK: - Primary Workout Session

    /// Called when iPhone launches this app via startWatchApp(with:).
    /// Uses locationType to distinguish Mode A (full recording) from Mode B (display-only).
    private func handleStartFromPhone(session: HKWorkoutSession) async {
        let locationType = session.workoutConfiguration.locationType
        wlog("[WATCH] handleStartFromPhone — locationType=\(locationType.rawValue), existing session=\(workoutSession != nil), starting=\(isStartingWorkout)")

        guard !isStartingWorkout else {
            wlog("[WATCH] handleStartFromPhone — BLOCKED: already starting")
            return
        }
        isStartingWorkout = true
        defer { isStartingWorkout = false }

        if workoutSession != nil {
            wlog("[WATCH] handleStartFromPhone — stale session exists, ending it before proceeding")
            endPrimaryWorkout()
            // Give the old session a moment to clean up
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        self.workoutSession = session
        session.delegate = self

        if locationType == .outdoor {
            // Mode B: Display-only — no builder, no HR recording, no duplicate workout saved.
            wlog("[WATCH] Mode B display session starting")
            session.startActivity(with: Date())
            self.workoutState = "running"
            wlog("[WATCH] Mode B session started")
        } else {
            // Mode A: Full recording with HR collection and mirroring back to iPhone.
            wlog("[WATCH] Mode A full recording session starting — requesting auth")
            await requestAuthorization()

            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: session.workoutConfiguration
            )
            self.workoutBuilder = builder
            wlog("[WATCH] Mode A builder created")

            session.startActivity(with: Date())
            self.workoutState = "running"
            wlog("[WATCH] Mode A session started, beginning collection + mirroring")

            Task {
                do {
                    try await builder.beginCollection(at: Date())
                    wlog("[WATCH] beginCollection succeeded")

                    // Verify session is still alive after beginCollection
                    guard session.state == .running else {
                        wlog("[WATCH] handleStartFromPhone: session died after beginCollection (state=\(session.state.rawValue)), aborting")
                        self.workoutSession = nil
                        self.workoutBuilder = nil
                        self.workoutState = "ended"
                        return
                    }

                    self.startHRObservation()
                } catch {
                    wlog("[WATCH] beginCollection FAILED: \(error.localizedDescription)")
                }
                await startMirroringWithRetry(session: session, maxAttempts: 3)
            }
        }
    }

    /// Start a primary workout session (called from WCSession message as backup).
    func startPrimaryWorkout() {
        wlog("[WATCH] startPrimaryWorkout — existing session=\(workoutSession != nil), starting=\(isStartingWorkout)")
        guard workoutSession == nil, !isStartingWorkout else {
            wlog("[WATCH] startPrimaryWorkout — BLOCKED: session exists or already starting")
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            self.workoutSession = session

            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            self.workoutState = "running"
            wlog("[WATCH] startPrimaryWorkout session started")

            Task {
                do {
                    try await builder.beginCollection(at: Date())
                    wlog("[WATCH] startPrimaryWorkout beginCollection succeeded")

                    // Verify session is still alive after beginCollection
                    guard session.state == .running else {
                        wlog("[WATCH] startPrimaryWorkout: session died after beginCollection (state=\(session.state.rawValue)), aborting")
                        self.workoutSession = nil
                        self.workoutBuilder = nil
                        self.workoutState = "ended"
                        return
                    }

                    self.startHRObservation()
                } catch {
                    wlog("[WATCH] startPrimaryWorkout beginCollection FAILED: \(error.localizedDescription)")
                }
                await startMirroringWithRetry(session: session, maxAttempts: 3)
            }
        } catch {
            wlog("[WATCH] startPrimaryWorkout session creation FAILED: \(error.localizedDescription)")
        }
    }

    /// Start a display-only session (no builder, no HR collection, no saved workout).
    /// Used in Mode B (BLE HR strap on iPhone) to keep the Watch app alive in the background.
    func startDisplaySession() {
        wlog("[WATCH] startDisplaySession — existing session=\(workoutSession != nil)")
        guard workoutSession == nil else {
            wlog("[WATCH] startDisplaySession — BLOCKED: workoutSession already exists")
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.delegate = self
            self.workoutSession = session
            // No builder — nothing will be recorded or saved
            session.startActivity(with: Date())
            self.workoutState = "running"
            wlog("[WATCH] startDisplaySession started (no builder, no recording)")
        } catch {
            wlog("[WATCH] startDisplaySession FAILED: \(error.localizedDescription)")
        }
    }

    func endPrimaryWorkout() {
        wlog("[WATCH] endPrimaryWorkout — session=\(workoutSession != nil), builder=\(workoutBuilder != nil), mirroring=\(mirroringEstablished)")
        guard let session = workoutSession else {
            workoutState = "ended"
            mirroringEstablished = false
            return
        }
        let builder = workoutBuilder
        self.workoutSession = nil
        self.workoutBuilder = nil
        self.mirroringEstablished = false
        self.isStartingWorkout = false
        self.loggedWCSessionFallback = false
        self.wcUpdateCount = 0
        self.lastMirroringRetryAt = nil
        stopHRObservation()

        session.stopActivity(with: Date())

        Task {
            if let builder = builder {
                // Mode A: save the workout
                do {
                    try await builder.endCollection(at: Date())
                    try await builder.finishWorkout()
                    wlog("[WATCH] endPrimaryWorkout: workout saved to HealthKit")
                } catch {
                    wlog("[WATCH] endPrimaryWorkout: save FAILED: \(error.localizedDescription)")
                }
            }
            // Mode B (no builder): just end the session — nothing saved
            session.end()
            self.workoutState = "ended"
            wlog("[WATCH] endPrimaryWorkout complete")
            self.sendLogToPhone()
        }
    }

    // MARK: - Mirroring

    private func startMirroringWithRetry(session: HKWorkoutSession, maxAttempts: Int) async {
        for attempt in 1...maxAttempts {
            guard workoutSession != nil else {
                wlog("[WATCH] startMirroringWithRetry: session ended, aborting")
                return
            }
            wlog("[WATCH] startMirroringToCompanionDevice attempt \(attempt)/\(maxAttempts)")
            do {
                try await session.startMirroringToCompanionDevice()
                mirroringEstablished = true
                wlog("[WATCH] startMirroringToCompanionDevice SUCCEEDED on attempt \(attempt)")
                return
            } catch {
                wlog("[WATCH] startMirroringToCompanionDevice FAILED attempt \(attempt): \(error.localizedDescription)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                }
            }
        }
        // All mirroring attempts failed — fall back to WCSession for display data
        wlog("[WATCH] All mirroring attempts failed. WCSession display updates will be used as fallback.")
    }

    // MARK: - HR Observation (read-only, no write permission needed)

    /// Start observing HR directly from HealthKit. Uses READ permission only,
    /// bypassing HKLiveWorkoutDataSource which silently fails without write permission.
    private func startHRObservation() {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        let handleSamples: ([HKSample]?) -> Void = { [weak self] samples in
            guard let samples = samples as? [HKQuantitySample],
                  let latest = samples.last else { return }
            let unit = HKUnit.count().unitDivided(by: .minute())
            let bpm = Int(latest.quantity.doubleValue(for: unit))
            guard bpm > 0 else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.heartRate == 0 {
                    self.wlog("[WATCH] HR first reading (query): \(bpm) bpm")
                }
                self.heartRate = bpm
                self.sendHRToPhone(bpm)
            }
        }

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { _, samples, _, _, _ in
            handleSamples(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in
            handleSamples(samples)
        }

        hrQuery = query
        healthStore.execute(query)
        wlog("[WATCH] HR observation query started")
    }

    private func stopHRObservation() {
        if let query = hrQuery {
            healthStore.stop(query)
            hrQuery = nil
        }
    }

    // MARK: - Time Formatting

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

// MARK: - HKWorkoutSessionDelegate

extension WatchSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        wlog("[WATCH] session state changed: \(fromState.rawValue) → \(toState.rawValue)")
        Task { @MainActor in
            switch toState {
            case .running:
                self.workoutState = "running"
            case .paused:
                self.workoutState = "paused"
            case .stopped:
                // Don't set "ended" here — wait for endPrimaryWorkout to finish saving
                break
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        let description = error.localizedDescription
        wlog("[WATCH] session FAILED: \(description)")

        // watchOS refuses to start HKWorkoutSession when the Watch app is
        // backgrounded. Tell the iPhone so it can prompt the user to wake
        // the Watch, and tear down the dead session so a retry can proceed.
        let isBackgroundStart = description.localizedCaseInsensitiveContains("background")
        guard isBackgroundStart else { return }

        wlog("[WATCH] session FAILED — background-start detected, notifying iPhone")
        if WCSession.isSupported() {
            let wc = WCSession.default
            if wc.isReachable {
                wc.sendMessage(
                    ["type": "watchError", "kind": "backgroundStart"],
                    replyHandler: nil,
                    errorHandler: nil
                )
            }
            wc.transferUserInfo([
                "type": "watchError",
                "kind": "backgroundStart",
                "timestamp": Date().timeIntervalSince1970
            ])
        }

        Task { @MainActor in
            self.workoutSession = nil
            self.workoutBuilder = nil
            self.mirroringEstablished = false
            self.isStartingWorkout = false
            self.loggedWCSessionFallback = false
            self.wcUpdateCount = 0
            self.workoutState = "ended"
            self.stopHRObservation()
            self.wlog("[WATCH] session FAILED cleanup complete — ready for retry")
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor in
            for datum in data {
                guard let update = try? JSONDecoder().decode(PhoneToWatchData.self, from: datum) else {
                    wlog("[WATCH] didReceiveDataFromRemote: decode failed")
                    continue
                }

                self.power = update.power
                self.elapsedTime = update.elapsedTime
                self.chunkRemaining = update.chunkRemaining
                self.currentChunk = update.currentChunk
                self.totalChunks = update.totalChunks

                // Handle state changes from iPhone
                switch update.state {
                case "paused":
                    if workoutSession.state == .running {
                        workoutSession.pause()
                    }
                case "running":
                    if workoutSession.state == .paused {
                        workoutSession.resume()
                    }
                case "ended":
                    self.endPrimaryWorkout()
                default:
                    break
                }
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        wlog("[WATCH] mirroring disconnected: \(error?.localizedDescription ?? "no error")")
        Task { @MainActor in
            self.mirroringEstablished = false

            guard self.workoutSession != nil else { return }
            wlog("[WATCH] attempting to re-mirror after disconnect...")
            await self.startMirroringWithRetry(session: workoutSession, maxAttempts: 3)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            let hrType = HKQuantityType(.heartRate)
            guard collectedTypes.contains(hrType) else { return }

            if let stats = workoutBuilder.statistics(for: hrType),
               let quantity = stats.mostRecentQuantity() {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = Int(quantity.doubleValue(for: unit))
                if self.heartRate == 0 {
                    wlog("[WATCH] HR first sample: \(bpm) bpm — collection working")
                }
                self.heartRate = bpm
                self.sendHRToPhone(bpm)
            }
        }
    }

    private func sendHRToPhone(_ heartRate: Int) {
        if mirroringEstablished {
            // Primary path: mirrored session data channel
            guard let session = workoutSession else {
                wlog("[WATCH] sendHRToPhone: no session, cannot send")
                return
            }
            guard let encoded = try? JSONEncoder().encode(WatchToPhoneData(heartRate: heartRate)) else { return }
            Task { @MainActor in
                do {
                    try await session.sendToRemoteWorkoutSession(data: encoded)
                } catch {
                    wlog("[WATCH] sendHRToPhone FAILED: \(error.localizedDescription)")
                    // The mirrored session is dead even though didDisconnectFromRemote
                    // wasn't called. Flip the flag and re-route via WCSession so HR
                    // doesn't black-hole until the next disconnect event (which may
                    // never come).
                    self.mirroringEstablished = false
                    self.sendHRViaWCSession(heartRate)
                    // Throttled re-mirror: only try once every 30s so we don't loop
                    // when startMirroringToCompanionDevice reports success but the
                    // channel is still broken on iPhone's side.
                    let now = Date()
                    if let last = self.lastMirroringRetryAt, now.timeIntervalSince(last) < 30 {
                        return
                    }
                    self.lastMirroringRetryAt = now
                    await self.startMirroringWithRetry(session: session, maxAttempts: 3)
                }
            }
        } else {
            sendHRViaWCSession(heartRate)
        }
    }

    private func sendHRViaWCSession(_ heartRate: Int) {
        guard let wc = wcSession, wc.isReachable else { return }
        if !loggedWCSessionFallback {
            wlog("[WATCH] sendHRToPhone: using WCSession fallback (mirroring not established)")
            loggedWCSessionFallback = true
        }
        wc.sendMessage(["type": "heartRateUpdate", "heartRate": heartRate], replyHandler: nil, errorHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        wlog("[WATCH] WCSession activated — reachable=\(session.isReachable), error=\(error?.localizedDescription ?? "none")")
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        wlog("[WATCH] WCSession reachability changed: \(session.isReachable)")
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        wlog("[WATCH] WCSession message received: \(type)")

        Task { @MainActor in
            switch type {
            case "startWorkout":
                // Backup trigger from iPhone (in case startWatchApp didn't fire the handler)
                wlog("[WATCH] WCSession startWorkout — existing session=\(self.workoutSession != nil)")
                await self.requestAuthorization()
                self.startPrimaryWorkout()

            case "startDisplayWorkout":
                // Mode B: Watch is display-only (HR strap on iPhone). Start a session
                // so watchOS keeps the app alive in the background for update delivery.
                wlog("[WATCH] WCSession startDisplayWorkout")
                await self.requestAuthorization()
                self.startDisplaySession()

            case "stopWorkout":
                wlog("[WATCH] WCSession stopWorkout")
                self.endPrimaryWorkout()

            case "pauseWorkout":
                wlog("[WATCH] WCSession pauseWorkout")
                self.workoutSession?.pause()

            case "resumeWorkout":
                wlog("[WATCH] WCSession resumeWorkout")
                self.workoutSession?.resume()

            case "workoutUpdate":
                // Always accept WCSession display updates. The iPhone only sends these
                // when IT believes mirroring isn't working. If the Watch also believes
                // mirroring is up but it's actually broken (e.g. "Another session in
                // progress"), the iPhone is the authority — trust its signal and display
                // the data. Duplicate updates from a working mirror are harmless.
                self.wcUpdateCount += 1
                if self.wcUpdateCount == 1 || self.wcUpdateCount % 30 == 0 {
                    wlog("[WATCH] WCSession workoutUpdate #\(self.wcUpdateCount) accepted")
                }
                self.heartRate = message["heartRate"] as? Int ?? self.heartRate
                self.power = message["power"] as? Int ?? self.power
                self.elapsedTime = message["elapsedTime"] as? TimeInterval ?? self.elapsedTime
                self.chunkRemaining = message["chunkRemaining"] as? TimeInterval ?? self.chunkRemaining
                self.currentChunk = message["currentChunk"] as? Int ?? self.currentChunk
                self.totalChunks = message["totalChunks"] as? Int ?? self.totalChunks
                self.workoutState = message["state"] as? String ?? self.workoutState

            case "workoutEnded":
                wlog("[WATCH] WCSession workoutEnded")
                self.endPrimaryWorkout()

            default:
                break
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let type = userInfo["type"] as? String else { return }
        wlog("[WATCH] WCSession userInfo received: \(type)")

        Task { @MainActor in
            switch type {
            case "startWorkout":
                // Guaranteed-delivery backup from iPhone via transferUserInfo
                wlog("[WATCH] userInfo startWorkout — existing session=\(self.workoutSession != nil)")
                guard self.workoutSession == nil else { return }
                await self.requestAuthorization()
                self.startPrimaryWorkout()

            case "stopWorkout", "workoutEnded":
                wlog("[WATCH] userInfo stop/ended")
                self.endPrimaryWorkout()

            default:
                break
            }
        }
    }
}
