import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showWorkout = false
    @State private var workoutViewModel: WorkoutViewModel?
    @State private var showZoneTargetingInfo = false
    @State private var showWarmUpInfo = false
    @State private var pendingRecovery: LocalWorkout?

    // Limit HR monitors to avoid crowded gyms filling the screen
    private var limitedHRMonitors: [DeviceInfo] {
        Array(viewModel.discoveredHRMonitors.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 10) {
                // Recovery Banner
                if let recovery = pendingRecovery {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recover Workout?")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Your workout was interrupted. Resume from \(formatElapsed(recovery.elapsedTime)).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            Button("Discard") {
                                LocalWorkoutStore.shared.delete(id: recovery.id)
                                pendingRecovery = nil
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemFill))
                            .cornerRadius(8)

                            Button("Resume") {
                                resumeRecoveredWorkout(recovery)
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }

                // Workout Configuration — the hero panel
                configCard

                // Devices section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("DEVICES")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.2)

                        Spacer()

                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(0.7)
                        }

                        Button(viewModel.isScanning ? "Stop" : "Scan") {
                            if viewModel.isScanning {
                                viewModel.stopScanning()
                            } else {
                                viewModel.startScanning()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.green.opacity(0.16)))
                        .foregroundStyle(.green)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 0) {
                            if !viewModel.isBluetoothEnabled {
                                Label("Bluetooth disabled", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.vertical, 8)
                            }

                            // Smart Trainers
                            if viewModel.discoveredKickrs.isEmpty && !viewModel.kickrConnected {
                                Label("No trainers found", systemImage: "bicycle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }
                            ForEach(Array(viewModel.discoveredKickrs.enumerated()), id: \.element.id) { idx, device in
                                if idx > 0 { Divider() }
                                DeviceRow(
                                    device: device,
                                    isConnected: viewModel.connectedKickrId == device.id,
                                    isConnecting: viewModel.kickrConnecting && viewModel.connectedKickrId == device.id,
                                    onConnect: { viewModel.connectKickr(device) },
                                    onDisconnect: { viewModel.disconnectKickr() }
                                )
                            }

                            // Heart Rate Monitors
                            if !viewModel.useWatchHR || !viewModel.discoveredHRMonitors.isEmpty || viewModel.hrConnected {
                                Divider()

                                HStack {
                                    if viewModel.discoveredHRMonitors.isEmpty && !viewModel.hrConnected {
                                        Label("No HR monitors found", systemImage: "heart")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if viewModel.discoveredHRMonitors.count > 3 {
                                        Spacer()
                                        Text("\(viewModel.discoveredHRMonitors.count) nearby")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, viewModel.discoveredHRMonitors.isEmpty && !viewModel.hrConnected ? 8 : 0)
                            }
                            ForEach(Array(limitedHRMonitors.enumerated()), id: \.element.id) { idx, device in
                                if idx > 0 { Divider() }
                                DeviceRow(
                                    device: device,
                                    isConnected: viewModel.connectedHRId == device.id,
                                    isConnecting: viewModel.hrConnecting && viewModel.connectedHRId == device.id,
                                    batteryLevel: viewModel.connectedHRId == device.id ? viewModel.hrBatteryLevel : nil,
                                    onConnect: { viewModel.connectHeartRateMonitor(device) },
                                    onDisconnect: { viewModel.disconnectHeartRateMonitor() }
                                )
                            }

                            // Apple Watch HR option
                            if viewModel.isWatchAvailable {
                                Divider()

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        iconChip("applewatch", tint: viewModel.useWatchHR ? .green : .secondary)
                                        Text("Apple Watch")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(viewModel.isWatchAppInstalled ? .primary : .secondary)
                                        Spacer()
                                        if viewModel.useWatchHR {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption)
                                                Text("Selected")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.green.opacity(0.1))
                                            .foregroundColor(.green)
                                            .clipShape(Capsule())
                                        } else if viewModel.isWatchAppInstalled {
                                            Button("Select") {
                                                viewModel.selectWatchHR()
                                            }
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(Color.blue.opacity(0.18)))
                                            .foregroundColor(.blue)
                                        } else {
                                            Text("Not installed")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard viewModel.isWatchAppInstalled else { return }
                                        if viewModel.useWatchHR {
                                            viewModel.deselectWatchHR()
                                        } else {
                                            viewModel.selectWatchHR()
                                        }
                                    }

                                    if !viewModel.isWatchAppInstalled {
                                        Label("Install JustZone2 on your Watch to enable", systemImage: "applewatch.slash")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, 6)
                                    } else if viewModel.useWatchHR {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 6, height: 6)
                                            Text("Watch HR will start with workout")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.bottom, 6)
                                    }
                                }
                            }

                            // AirPods Pro HR option (Pro 3+ in-ear HR sensor)
                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    iconChip("airpodspro", tint: viewModel.hrSource == .airPods ? .green : .secondary)
                                    Text("AirPods Pro")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    if viewModel.hrSource == .airPods {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                            Text("Selected")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                    } else {
                                        Button("Select") {
                                            viewModel.hrSource = .airPods
                                            viewModel.heartRateService.disconnect()
                                            viewModel.hrConnected = false
                                            viewModel.hrConnecting = false
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.hrSource == .airPods {
                                        viewModel.hrSource = .bleStrap
                                    } else {
                                        viewModel.hrSource = .airPods
                                        viewModel.heartRateService.disconnect()
                                        viewModel.hrConnected = false
                                        viewModel.hrConnecting = false
                                    }
                                }

                                if viewModel.hrSource == .airPods {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text("Wear AirPods Pro 3 during workout — HR auto-detected")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .glassCard()
                }

                // Integrations section — compact, side-by-side
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Integrations", systemImage: "app.connected.to.app.below.fill")

                    HStack(spacing: 10) {
                        integrationTile(
                            icon: "heart.fill", tint: .pink, title: "Apple Health",
                            connected: viewModel.isHealthKitAuthorized,
                            connect: { Task { await viewModel.requestHealthKitAuthorization() } }
                        )
                        integrationTile(
                            icon: "figure.outdoor.cycle", tint: Self.stravaOrange, title: "Strava",
                            connected: viewModel.isStravaConnected,
                            connect: { Task { await viewModel.connectToStrava() } }
                        )
                    }
                }

                // Start — pinned at the bottom. Mode A (Apple Watch HR) is
                // started from the Watch, so we show a prompt instead of a
                // button; all other modes start from this button.
                if viewModel.useWatchHR {
                    watchStartPrompt
                } else {
                    Button(action: { buildAndNavigateToWorkout() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Start Workout")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if viewModel.canStartWorkout {
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.78)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            } else {
                                Color.gray.opacity(0.4)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(
                            color: viewModel.canStartWorkout ? Color.green.opacity(0.35) : .clear,
                            radius: 10, y: 4
                        )
                    }
                    .disabled(!viewModel.canStartWorkout)

                    if !viewModel.canStartWorkout {
                        Text(viewModel.startButtonHelpText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(
                ZStack {
                    Color(.systemGroupedBackground)
                    RadialGradient(
                        colors: [Color.green.opacity(0.18), Color.clear],
                        center: .top, startRadius: 0, endRadius: 360
                    )
                }
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Justzone2")
                        .font(.custom("ArialRoundedMTBold", size: 28))
                        .foregroundColor(.green)
                }
            }
            .navigationDestination(isPresented: $showWorkout) {
                if let workoutVM = workoutViewModel {
                    WorkoutView(
                        viewModel: workoutVM,
                        stravaService: viewModel.stravaService,
                        isPresented: $showWorkout
                    )
                }
            }
            .onChange(of: showWorkout) { oldValue, newValue in
                if !newValue {
                    // Stop KICKR (may still be at cool-down power) then clean up
                    viewModel.kickrService.stopWorkout()
                    workoutViewModel = nil
                    // Back on Setup: clear the consumed Watch-start signal and
                    // re-arm the Watch for the next ride.
                    viewModel.clearWatchStartedFlag()
                    viewModel.armWatchStartIfReady()
                }
            }
            // Mode A: when everything's ready, arm the already-open Watch app so
            // its Start button appears. Only while we're on the setup screen —
            // mid-workout (showWorkout) reachability flaps would otherwise spam
            // the Watch with prepareWorkout messages it ignores anyway.
            .onChange(of: viewModel.canStartWorkout) { _, _ in
                if !showWorkout { viewModel.armWatchStartIfReady() }
            }
            .onChange(of: viewModel.useWatchHR) { _, _ in
                if !showWorkout { viewModel.armWatchStartIfReady() }
            }
            // Mode A: the user pressed Start on the Watch — begin + navigate.
            .onChange(of: viewModel.watchStartedWorkout) { _, started in
                guard started else { return }
                // Already in a workout (e.g. a mid-ride revive re-sent
                // watchDidStart): just consume the signal, don't disturb it.
                guard !showWorkout, workoutViewModel == nil else {
                    viewModel.clearWatchStartedFlag()
                    return
                }
                if viewModel.useWatchHR, viewModel.canStartWorkout {
                    buildAndNavigateToWorkout()
                } else {
                    // Watch started but the phone can't run this workout (trainer
                    // dropped, or HR source no longer the Watch) — stand the Watch
                    // session back down so it isn't left running orphaned.
                    viewModel.watchConnectivityService.sendStopWorkout()
                    viewModel.clearWatchStartedFlag()
                }
            }
            .sheet(isPresented: $showZoneTargetingInfo) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Zone Targeting uses a PID controller to automatically adjust your trainer's power and keep your heart rate at the midpoint of your Zone 2 range.")

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Targets the midpoint of your Zone 2 range using a PID controller", systemImage: "heart.text.square.fill")
                                Label("Uses a 45-second rolling average of your heart rate to avoid reacting to brief spikes", systemImage: "heart.fill")
                                Label("Adjusts power smoothly and continuously, up to ±30W from your target", systemImage: "plusminus")
                                Label("Ramps up slowly (5W/90s) and backs off faster (5W/45s) for safety", systemImage: "arrow.up.arrow.down")
                                Label("Skips the first 3 minutes, then holds power steady until your heart rate reaches zone", systemImage: "figure.walk")
                            }
                            .font(.subheadline)

                            Text("Set your Zone 2 heart rate range in Settings.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    .navigationTitle("Zone Targeting")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showZoneTargetingInfo = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showWarmUpInfo) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Warm Up eases you into the workout by starting at a lower power.")

                            VStack(alignment: .leading, spacing: 8) {
                                Label("First 60 seconds at half your target power", systemImage: "flame")
                                Label("Gives your legs and heart rate time to ramp up naturally", systemImage: "heart.fill")
                                Label("Warm-up time counts toward total workout duration", systemImage: "timer")
                            }
                            .font(.subheadline)
                        }
                        .padding()
                    }
                    .navigationTitle("Warm Up")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showWarmUpInfo = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .onAppear {
            viewModel.bluetoothManager.checkBluetoothState()
            // Small delay to allow Bluetooth state to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.startScanning()
            }
            // Check HealthKit authorization
            viewModel.healthKitManager.checkAuthorizationStatus()
            // Check for in-progress workout to recover (samples + settings preserved)
            if pendingRecovery == nil, let local = LocalWorkoutStore.shared.mostRecentInProgress() {
                pendingRecovery = local
            }
            // Drop any stale "Watch started" signal, then arm the Watch if we're
            // already ready (Mode A).
            viewModel.clearWatchStartedFlag()
            viewModel.armWatchStartIfReady()
        }
    }

    // MARK: - Hero configuration panel

    /// The headline card: target power + duration as glass "stat" tiles, then the
    /// Zone Targeting / Warm Up options, all on a soft green-gradient panel.
    private var configCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PowerPicker(
                    selectedPower: $viewModel.targetPower,
                    options: viewModel.powerOptions
                )
                .frame(maxWidth: .infinity)

                DurationPicker(
                    selectedDuration: $viewModel.targetDuration,
                    options: viewModel.durationOptions,
                    formatDuration: viewModel.formatDuration
                )
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                configToggleTile(
                    icon: "target", tint: .green, title: "Zone Targeting",
                    isOn: $viewModel.zoneTargetingEnabled,
                    info: { showZoneTargetingInfo = true }
                )
                configToggleTile(
                    icon: "flame.fill", tint: .orange, title: "Warm Up",
                    isOn: $viewModel.warmUpEnabled,
                    info: { showWarmUpInfo = true }
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.28), Color.green.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.green.opacity(0.30), lineWidth: 1)
        )
    }

    /// A compact half-width option tile (Zone Targeting / Warm Up) so the two sit
    /// side by side and keep the hero panel short.
    private func configToggleTile(
        icon: String, tint: Color, title: String,
        isOn: Binding<Bool>, info: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                iconChip(icon, tint: isOn.wrappedValue ? tint : .secondary)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(tint)
            }
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button(action: info) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    /// SF Symbol in a tinted rounded-square chip — the core "designed list" motif.
    private func iconChip(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
    }

    static let stravaOrange = Color(red: 0.99, green: 0.32, blue: 0)

    /// A subtle, designed section label: small glyph + tracked caps title.
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    /// Compact integration tile — icon chip, name, and a small status line.
    /// Tapping connects when not yet connected.
    private func integrationTile(
        icon: String, tint: Color, title: String,
        connected: Bool, connect: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            iconChip(icon, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(connected ? "Connected" : "Tap to connect")
                    .font(.caption2)
                    .foregroundStyle(connected ? .green : .secondary)
            }
            Spacer(minLength: 0)
            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
        .contentShape(Rectangle())
        .onTapGesture { if !connected { connect() } }
    }

    /// Mode A: the workout is started from the Apple Watch. Compact single-row
    /// prompt — the action is on the Watch, so the icon is an (animated) Watch
    /// glyph (never a phone-style play button) and the status line tells the user
    /// whether the Watch app is actually open.
    private var watchStartPrompt: some View {
        let ready = viewModel.canStartWorkout
        let watchOpen = viewModel.isWatchReachable
        let accent: Color = ready ? .green : .orange

        let icon: String
        let title: String
        let status: String
        if ready {
            icon = "applewatch.radiowaves.left.and.right"
            title = "Press Start on your Watch"
            status = "Watch app open — nothing to press here"
        } else if viewModel.watchHRWaitingForApp {
            icon = "applewatch.slash"
            title = "Open JustZone2 on your Watch"
            status = "Then press Start on the Watch"
        } else {
            icon = "exclamationmark.triangle.fill"
            title = viewModel.startButtonHelpText
            status = ""
        }

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: ready)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(watchOpen ? .green : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    /// Build a fresh WorkoutViewModel from the current setup and navigate to the
    /// workout screen. Used by the Mode B Start button and the Mode A
    /// Watch-initiated start.
    private func buildAndNavigateToWorkout() {
        let workout = viewModel.createWorkout()
        workoutViewModel = WorkoutViewModel(
            workout: workout,
            bluetoothManager: viewModel.bluetoothManager,
            kickrService: viewModel.kickrService,
            heartRateService: viewModel.heartRateService,
            healthKitManager: viewModel.healthKitManager,
            liveActivityManager: viewModel.liveActivityManager,
            watchConnectivityService: viewModel.watchConnectivityService,
            hrSource: viewModel.hrSource,
            zoneTargetingEnabled: viewModel.zoneTargetingEnabled,
            warmUpEnabled: viewModel.warmUpEnabled
        )
        showWorkout = true
    }

    private func resumeRecoveredWorkout(_ recovery: LocalWorkout) {
        let vm = WorkoutViewModel(
            workout: recovery.workout,
            bluetoothManager: viewModel.bluetoothManager,
            kickrService: viewModel.kickrService,
            heartRateService: viewModel.heartRateService,
            healthKitManager: viewModel.healthKitManager,
            liveActivityManager: viewModel.liveActivityManager,
            watchConnectivityService: viewModel.watchConnectivityService,
            hrSource: recovery.useWatchHR ? .appleWatch : .bleStrap,
            zoneTargetingEnabled: recovery.zoneTargetingEnabled,
            warmUpEnabled: recovery.warmUpEnabled
        )
        workoutViewModel = vm
        pendingRecovery = nil
        showWorkout = true

        // resumeRecoveredWorkout will start its own iPhone HK session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            vm.resumeRecoveredWorkout(elapsedTime: recovery.elapsedTime)
        }
    }

    private func formatElapsed(_ time: TimeInterval) -> String {
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

#Preview {
    let bluetoothManager = BluetoothManager()
    let kickrService = KickrService(bluetoothManager: bluetoothManager)
    let heartRateService = HeartRateService(bluetoothManager: bluetoothManager)
    let stravaService = StravaService()
    let healthKitManager = HealthKitManager()
    let liveActivityManager = LiveActivityManager()

    let watchConnectivityService = WatchConnectivityService()

    return SetupView(viewModel: SetupViewModel(
        bluetoothManager: bluetoothManager,
        kickrService: kickrService,
        heartRateService: heartRateService,
        stravaService: stravaService,
        healthKitManager: healthKitManager,
        liveActivityManager: liveActivityManager,
        watchConnectivityService: watchConnectivityService
    ))
}

// MARK: - Design helpers

private extension View {
    /// Frosted "liquid glass" card surface with a hairline border, used for the
    /// device + integration panels so they read as designed cards, not form rows.
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
