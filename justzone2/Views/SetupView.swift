import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showWorkout = false
    @State private var workoutViewModel: WorkoutViewModel?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Device Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Devices")
                            .font(.headlineSmall)

                        Spacer()

                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }

                        Button(action: {
                            if viewModel.isScanning {
                                viewModel.stopScanning()
                            } else {
                                viewModel.startScanning()
                            }
                        }) {
                            Text(viewModel.isScanning ? "Stop" : "Scan")
                                .font(.bodyMedium)
                        }
                    }

                    if !viewModel.isBluetoothEnabled {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Bluetooth is disabled. Enable it in Settings.")
                                .font(.labelMedium)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Smart Trainers (KICKR)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Trainers")
                            .font(.labelMedium)
                            .foregroundColor(.secondary)

                        if viewModel.discoveredKickrs.isEmpty && !viewModel.kickrConnected {
                            Text("No trainers found. Tap Scan to search.")
                                .font(.labelMedium)
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

                        if let error = viewModel.kickrError {
                            Text(error)
                                .font(.labelMedium)
                                .foregroundColor(.red)
                        }
                    }

                    Divider()

                    // Heart Rate Monitors
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Heart Rate Monitors")
                            .font(.labelMedium)
                            .foregroundColor(.secondary)

                        if viewModel.discoveredHRMonitors.isEmpty && !viewModel.hrConnected {
                            Text("No HR monitors found. Tap Scan to search.")
                                .font(.labelMedium)
                                .foregroundColor(.secondary)
                        }

                        ForEach(viewModel.discoveredHRMonitors) { device in
                            DeviceRow(
                                device: device,
                                isConnected: viewModel.hrConnected,
                                isConnecting: viewModel.hrConnecting,
                                onConnect: { viewModel.connectHeartRateMonitor(device) },
                                onDisconnect: { viewModel.disconnectHeartRateMonitor() }
                            )
                        }

                        if let error = viewModel.hrError {
                            Text(error)
                                .font(.labelMedium)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Health & Integrations Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Integrations")
                        .font(.headlineSmall)

                    // HealthKit
                    HStack {
                        Image(systemName: viewModel.isHealthKitAuthorized ? "heart.fill" : "heart")
                            .foregroundColor(viewModel.isHealthKitAuthorized ? .red : .gray)
                        Text("Apple Health")
                            .font(.bodyLarge)
                        Spacer()
                        if viewModel.isHealthKitAuthorized {
                            Text("Connected")
                                .font(.labelMedium)
                                .foregroundColor(.green)
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.requestHealthKitAuthorization()
                                }
                            }) {
                                Text("Connect")
                                    .font(.bodyMedium)
                            }
                        }
                    }

                    if let error = viewModel.healthKitError {
                        Text(error)
                            .font(.labelMedium)
                            .foregroundColor(.red)
                    }

                    Divider()

                    // Strava
                    HStack {
                        Image(systemName: viewModel.isStravaConnected ? "checkmark.circle.fill" : "link.circle")
                            .foregroundColor(viewModel.isStravaConnected ? .orange : .gray)
                        Text("Strava")
                            .font(.bodyLarge)
                        Spacer()
                        if viewModel.isStravaConnected {
                            Text("Connected")
                                .font(.labelMedium)
                                .foregroundColor(.green)
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.connectToStrava()
                                }
                            }) {
                                Text("Connect")
                                    .font(.bodyMedium)
                            }
                        }
                    }

                    if let error = viewModel.stravaError {
                        Text(error)
                            .font(.labelMedium)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                Spacer()

                // Start Button
                VStack(spacing: 8) {
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
                        .font(.headlineSmall)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canStartWorkout ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.canStartWorkout)

                    if !viewModel.canStartWorkout {
                        Text(viewModel.startButtonHelpText)
                            .font(.labelMedium)
                            .foregroundColor(.secondary)
                    }
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
