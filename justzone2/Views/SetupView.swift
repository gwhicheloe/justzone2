import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showWorkout = false
    @State private var workoutViewModel: WorkoutViewModel?

    // Limit HR monitors to avoid crowded gyms filling the screen
    private var limitedHRMonitors: [DeviceInfo] {
        Array(viewModel.discoveredHRMonitors.prefix(3))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Workout Configuration - side by side
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
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Device Section
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
                            isConnected: viewModel.kickrConnected,
                            isConnecting: viewModel.kickrConnecting,
                            onConnect: { viewModel.connectKickr(device) },
                            onDisconnect: { viewModel.disconnectKickr() }
                        )
                    }

                    Divider()

                    // Heart Rate Monitors (limited to 3)
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
                            isConnected: viewModel.hrConnected,
                            isConnecting: viewModel.hrConnecting,
                            onConnect: { viewModel.connectHeartRateMonitor(device) },
                            onDisconnect: { viewModel.disconnectHeartRateMonitor() }
                        )
                    }
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Integrations Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Integrations")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Label("Apple Health", systemImage: viewModel.isHealthKitAuthorized ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isHealthKitAuthorized ? .red : .primary)
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
                            .foregroundColor(viewModel.isStravaConnected ? .orange : .primary)
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
                        liveActivityManager: viewModel.liveActivityManager
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
            .navigationTitle("JustZone2")
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

    return SetupView(viewModel: SetupViewModel(
        bluetoothManager: bluetoothManager,
        kickrService: kickrService,
        heartRateService: heartRateService,
        stravaService: stravaService,
        healthKitManager: healthKitManager,
        liveActivityManager: liveActivityManager
    ))
}
