import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showWorkout = false
    @State private var workoutViewModel: WorkoutViewModel?
    @State private var showZoneTargetingInfo = false

    // Limit HR monitors to avoid crowded gyms filling the screen
    private var limitedHRMonitors: [DeviceInfo] {
        Array(viewModel.discoveredHRMonitors.prefix(3))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Workout Configuration
                VStack(spacing: 8) {
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

                    Divider()

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
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // Device Section
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Devices")
                                .font(.subheadline)
                                .fontWeight(.semibold)

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

                        if !viewModel.isBluetoothEnabled {
                            Label("Bluetooth disabled", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        // Smart Trainers
                        if viewModel.discoveredKickrs.isEmpty && !viewModel.kickrConnected {
                            Label("No trainers found", systemImage: "bicycle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ForEach(viewModel.discoveredKickrs) { device in
                            DeviceRow(
                                device: device,
                                isConnected: viewModel.connectedKickrId == device.id,
                                isConnecting: viewModel.kickrConnecting && viewModel.connectedKickrId == device.id,
                                onConnect: { viewModel.connectKickr(device) },
                                onDisconnect: { viewModel.disconnectKickr() }
                            )
                        }

                        Divider()

                        // Heart Rate Monitors
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
                        ForEach(limitedHRMonitors) { device in
                            DeviceRow(
                                device: device,
                                isConnected: viewModel.connectedHRId == device.id,
                                isConnecting: viewModel.hrConnecting && viewModel.connectedHRId == device.id,
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
                                    Text("Apple Watch")
                                        .font(.subheadline)
                                        .foregroundColor(viewModel.isWatchAppInstalled ? .primary : .secondary)
                                    Spacer()
                                    if viewModel.useWatchHR {
                                        HStack(spacing: 4) {
                                            Text("Selected")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    } else if viewModel.isWatchAppInstalled {
                                        Button("Select") {
                                            viewModel.selectWatchHR()
                                        }
                                        .font(.subheadline)
                                    }
                                }
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
                                } else if viewModel.useWatchHR {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text("Watch HR will start with workout")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: 260)

                // Integrations Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Integrations")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Label("Apple Health", systemImage: viewModel.isHealthKitAuthorized ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isHealthKitAuthorized ? .green : .primary)
                        Spacer()
                        if viewModel.isHealthKitAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Connect") {
                                Task { await viewModel.requestHealthKitAuthorization() }
                            }
                            .font(.subheadline)
                        }
                    }
                    .font(.subheadline)

                    Divider()

                    HStack {
                        Label("Strava", systemImage: viewModel.isStravaConnected ? "checkmark.circle.fill" : "link.circle")
                            .foregroundColor(viewModel.isStravaConnected ? .green : .primary)
                        Spacer()
                        if viewModel.isStravaConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Connect") {
                                Task { await viewModel.connectToStrava() }
                            }
                            .font(.subheadline)
                        }
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                Spacer()

                // Start Button
                Button(action: {
                    let workout = viewModel.createWorkout()
                    workoutViewModel = WorkoutViewModel(
                        workout: workout,
                        kickrService: viewModel.kickrService,
                        heartRateService: viewModel.heartRateService,
                        healthKitManager: viewModel.healthKitManager,
                        liveActivityManager: viewModel.liveActivityManager,
                        watchConnectivityService: viewModel.watchConnectivityService,
                        useWatchHR: viewModel.useWatchHR,
                        zoneTargetingEnabled: viewModel.zoneTargetingEnabled
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
                    Text(viewModel.startButtonHelpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    // Clean up when returning to setup
                    workoutViewModel = nil
                }
            }
            .sheet(isPresented: $showZoneTargetingInfo) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Zone Targeting automatically adjusts your trainer's power to keep your heart rate within your Zone 2 range.")

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Uses a 45-second rolling average of your heart rate to avoid reacting to brief spikes", systemImage: "heart.fill")
                                Label("Adjusts power in small 5W steps, up to ±30W from your target", systemImage: "plusminus")
                                Label("Waits 60–90 seconds between adjustments to let your heart rate settle", systemImage: "timer")
                                Label("Slower to decrease power than increase, so drink breaks don't ratchet you down", systemImage: "arrow.down.right")
                                Label("Skips the first 3 minutes to allow for warm-up", systemImage: "figure.walk")
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
        }
        .onAppear {
            viewModel.bluetoothManager.checkBluetoothState()
            // Small delay to allow Bluetooth state to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.startScanning()
            }
            // Check HealthKit authorization
            viewModel.healthKitManager.checkAuthorizationStatus()
        }
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
