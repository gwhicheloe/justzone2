import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showWorkout = false
    @State private var workoutViewModel: WorkoutViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout Configuration
                    VStack(spacing: 16) {
                        PowerPicker(
                            selectedPower: $viewModel.targetPower,
                            options: viewModel.powerOptions
                        )

                        DurationPicker(
                            selectedDuration: $viewModel.targetDuration,
                            options: viewModel.durationOptions,
                            formatDuration: viewModel.formatDuration
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    // Device Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Devices")
                                .font(.headline)

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
                                    .font(.subheadline)
                            }
                        }

                        if !viewModel.isBluetoothEnabled {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Bluetooth is disabled. Enable it in Settings.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Smart Trainers (KICKR)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Smart Trainers")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if viewModel.discoveredKickrs.isEmpty && !viewModel.kickrConnected {
                                Text("No trainers found. Tap Scan to search.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
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
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Divider()

                        // Heart Rate Monitors
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Heart Rate Monitors")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if viewModel.discoveredHRMonitors.isEmpty && !viewModel.hrConnected {
                                Text("No HR monitors found. Tap Scan to search.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
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
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                    // Start Button
                    Button(action: {
                        let workout = viewModel.createWorkout()
                        workoutViewModel = WorkoutViewModel(
                            workout: workout,
                            kickrService: viewModel.kickrService,
                            heartRateService: viewModel.heartRateService
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
                        .background(viewModel.isReadyToStart ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isReadyToStart)

                    if !viewModel.isReadyToStart {
                        Text("Connect your smart trainer to start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
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
            .onChange(of: showWorkout) { isShowing in
                if !isShowing {
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
        }
    }
}

#Preview {
    let bluetoothManager = BluetoothManager()
    let kickrService = KickrService(bluetoothManager: bluetoothManager)
    let heartRateService = HeartRateService(bluetoothManager: bluetoothManager)
    let stravaService = StravaService()

    return SetupView(viewModel: SetupViewModel(
        bluetoothManager: bluetoothManager,
        kickrService: kickrService,
        heartRateService: heartRateService,
        stravaService: stravaService
    ))
}
