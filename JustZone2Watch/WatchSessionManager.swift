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

    /// Prevents duplicate session starts when both mirroring handler and WCSession backup fire simultaneously.
    private var isStartingWorkout = false

    /// Counter for WCSession workoutUpdate messages — only log first and every 30th to reduce spam.
    private var wcUpdateCount = 0

    /// Sequence counter for HR samples sent to iPhone via WCSession.
    /// Lets the iPhone detect dropped samples by spotting gaps in the seq stream.
    private var hrSendSeq: Int = 0

    /// Direct HealthKit HR observation query — reads HR from system sensor data.
    /// Bypasses HKLiveWorkoutDataSource which requires write authorization.
    private var hrQuery: HKAnchoredObjectQuery?

    // MARK: - Watch-side log (sent to iPhone at workout end)

    /// Thread-safe log store — held as a `let` so nonisolated methods can access it safely.
    nonisolated(unsafe) private let watchLog = WatchLogStore()

    /// Callable from any isolation context (nonisolated delegates, completion handlers, etc.)
    nonisolated func wlog(_ message: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
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
            // Mode A: Watch records HR via its own session and ships HR to iPhone via WCSession.
            // We do NOT call startMirroringToCompanionDevice — Apple's mirrored data channel is
            // chronically broken on iOS/watchOS 26 (FB20723311). The session passed by
            // workoutSessionMirroringStartHandler is used as a normal local session.
            wlog("[WATCH] Mode A recording session starting — requesting auth")
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
            wlog("[WATCH] Mode A session started, beginning collection")

            Task {
                do {
                    try await builder.beginCollection(at: Date())
                    wlog("[WATCH] beginCollection succeeded")

                    // Verify session is still alive after beginCollection
                    guard session.state == .running else {
                        wlog("[WATCH] handleStartFromPhone: session died after beginCollection (state=\(hkStateName(session.state))), aborting")
                        self.workoutSession = nil
                        self.workoutBuilder = nil
                        self.workoutState = "ended"
                        return
                    }

                    self.startHRObservation()
                } catch {
                    wlog("[WATCH] beginCollection FAILED: \(error.localizedDescription)")
                }
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
                        wlog("[WATCH] startPrimaryWorkout: session died after beginCollection (state=\(hkStateName(session.state))), aborting")
                        self.workoutSession = nil
                        self.workoutBuilder = nil
                        self.workoutState = "ended"
                        return
                    }

                    self.startHRObservation()
                } catch {
                    wlog("[WATCH] startPrimaryWorkout beginCollection FAILED: \(error.localizedDescription)")
                }
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
        wlog("[WATCH] endPrimaryWorkout — session=\(workoutSession != nil), builder=\(workoutBuilder != nil), hrSent=\(hrSendSeq)")
        guard let session = workoutSession else {
            workoutState = "ended"
            return
        }
        let builder = workoutBuilder
        self.workoutSession = nil
        self.workoutBuilder = nil
        self.isStartingWorkout = false
        self.wcUpdateCount = 0
        self.hrSendSeq = 0
        stopHRObservation()

        session.stopActivity(with: Date())

        Task {
            if let builder = builder {
                // iPhone owns the HealthKit workout record; Watch's builder is
                // only used for HR collection access. Discard so we don't end
                // up with two workout entries in Health.
                do {
                    try await builder.endCollection(at: Date())
                    try await builder.discardWorkout()
                    wlog("[WATCH] endPrimaryWorkout: builder discarded (iPhone owns the record)")
                } catch {
                    wlog("[WATCH] endPrimaryWorkout: discard FAILED: \(error.localizedDescription)")
                }
            }
            // Mode B (no builder): nothing was being recorded.
            session.end()
            self.workoutState = "ended"
            wlog("[WATCH] endPrimaryWorkout complete")
            self.sendLogToPhone()
        }
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
        wlog("[WATCH] session state: \(hkStateName(fromState)) → \(hkStateName(toState))")
        wsignpost("Watch session \(hkStateName(toState))")
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
            self.isStartingWorkout = false
            self.wcUpdateCount = 0
            self.hrSendSeq = 0
            self.workoutState = "ended"
            self.stopHRObservation()
            self.wlog("[WATCH] session FAILED cleanup complete — ready for retry")
        }
    }

    // didReceiveDataFromRemoteWorkoutSession and didDisconnectFromRemoteDeviceWithError
    // are no longer relevant — we don't open a mirrored data channel. iPhone pushes
    // display data (power, elapsed, state) over WCSession workoutUpdate messages
    // and HR is sent back the same way.
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

    /// HR sample → iPhone, single channel: WCSession sendMessage with monotonic seq.
    /// Periodic counter log (every 30 samples) lets us spot black-holes in shipped diagnostics.
    private func sendHRToPhone(_ heartRate: Int) {
        guard let wc = wcSession else { return }
        hrSendSeq += 1
        let seq = hrSendSeq

        if seq == 1 {
            wlog("[WATCH] HR first send seq=\(seq) bpm=\(heartRate) — \(wcSnapshot(wc))")
        } else if seq % 30 == 0 {
            wlog("[WATCH] HR send #\(seq) bpm=\(heartRate) — \(wcSnapshot(wc))")
        }

        guard wc.isReachable else {
            // Don't spam — only log first drop and every 30th
            if seq == 1 || seq % 30 == 0 {
                wlog("[WATCH] HR DROPPED — not reachable seq=\(seq) — \(wcSnapshot(wc))")
            }
            return
        }
        wc.sendMessage(
            ["type": "heartRateUpdate", "heartRate": heartRate, "seq": seq],
            replyHandler: nil
        ) { [weak self] error in
            self?.wlog("[WATCH] HR sendMessage FAILED seq=\(seq): \(error.localizedDescription)")
        }
        wsignpost("Watch→iPhone HR=\(heartRate) seq=\(seq)")
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
                // iPhone pushes power/elapsed/state to Watch ~1 Hz via WCSession.
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
