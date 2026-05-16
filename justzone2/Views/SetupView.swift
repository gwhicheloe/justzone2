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
            VStack(spacing: 12) {
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

                // Workout Configuration
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
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
                    .padding(.bottom, 4)

                    Divider().padding(.vertical, 6)

                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(viewModel.zoneTargetingEnabled ? .green : .secondary)
                        Text("Zone Targeting")
                            .font(.subheadline)
                        Button {
                            showZoneTargetingInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.zoneTargetingEnabled)
                            .labelsHidden()
                            .tint(.green)
                    }

                    Divider().padding(.vertical, 6)

                    HStack {
                        Image(systemName: "flame")
                            .foregroundColor(viewModel.warmUpEnabled ? .orange : .secondary)
                        Text("Warm Up")
                            .font(.subheadline)
                        Button {
                            showWarmUpInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.warmUpEnabled)
                            .labelsHidden()
                            .tint(.green)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // Devices section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("DEVICES")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(.secondary)

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
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 4)

                    ScrollView {
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
                                        Image(systemName: "applewatch")
                                            .foregroundColor(viewModel.useWatchHR ? .green : viewModel.isWatchAppInstalled ? .primary : .secondary)
                                            .frame(width: 30)
                                        Text("Apple Watch")
                                            .font(.subheadline)
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
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        }
                        .padding(.horizontal, 12)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .frame(maxHeight: 240)
                }

                // Integrations section
                VStack(alignment: .leading, spacing: 6) {
                    Text("INTEGRATIONS")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: viewModel.isHealthKitAuthorized ? "heart.fill" : "heart")
                                .foregroundColor(viewModel.isHealthKitAuthorized ? .green : .secondary)
                                .frame(width: 30)
                            Text("Apple Health")
                                .font(.subheadline)
                            Spacer()
                            if viewModel.isHealthKitAuthorized {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("Connect") {
                                    Task { await viewModel.requestHealthKitAuthorization() }
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.vertical, 8)

                        Divider()

                        HStack {
                            Image(systemName: viewModel.isStravaConnected ? "checkmark.circle.fill" : "link.circle")
                                .foregroundColor(viewModel.isStravaConnected ? .green : Color(red: 0.99, green: 0.32, blue: 0))
                                .frame(width: 30)
                            Text("Strava")
                                .font(.subheadline)
                            Spacer()
                            if viewModel.isStravaConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("Connect") {
                                    Task { await viewModel.connectToStrava() }
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.99, green: 0.32, blue: 0).opacity(0.1))
                                .foregroundColor(Color(red: 0.99, green: 0.32, blue: 0))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }

                // Start Button — always pinned at the bottom
                Button(action: {
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
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canStartWorkout ? Color.green : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canStartWorkout)

                if !viewModel.canStartWorkout {
                    HStack(spacing: 6) {
                        if viewModel.watchHRWaitingForApp {
                            Image(systemName: "applewatch")
                                .foregroundColor(.orange)
                        }
                        Text(viewModel.startButtonHelpText)
                            .foregroundColor(viewModel.watchHRWaitingForApp ? .orange : .secondary)
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
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
        }
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
