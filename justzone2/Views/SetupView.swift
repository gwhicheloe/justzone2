import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @State private var showWorkout = false
    @State private var workout: Workout?

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

                            if viewModel.bluetoothManager.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }

                            Button(action: {
                                if viewModel.bluetoothManager.isScanning {
                                    viewModel.stopScanning()
                                } else {
                                    viewModel.startScanning()
                                }
                            }) {
                                Text(viewModel.bluetoothManager.isScanning ? "Stop" : "Scan")
                                    .font(.subheadline)
                            }
                        }

                        if !viewModel.bluetoothManager.isBluetoothEnabled {
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

                            if viewModel.bluetoothManager.discoveredKickrs.isEmpty && !viewModel.kickrService.isConnected {
                                Text("No trainers found. Tap Scan to search.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }

                            ForEach(viewModel.bluetoothManager.discoveredKickrs) { device in
                                DeviceRow(
                                    device: device,
                                    isConnected: viewModel.kickrService.isConnected,
                                    onConnect: { viewModel.connectKickr(device) },
                                    onDisconnect: { viewModel.disconnectKickr() }
                                )
                            }

                            if let error = viewModel.kickrService.connectionError {
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

                            if viewModel.bluetoothManager.discoveredHRMonitors.isEmpty && !viewModel.heartRateService.isConnected {
                                Text("No HR monitors found. Tap Scan to search.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }

                            ForEach(viewModel.bluetoothManager.discoveredHRMonitors) { device in
                                DeviceRow(
                                    device: device,
                                    isConnected: viewModel.heartRateService.isConnected,
                                    onConnect: { viewModel.connectHeartRateMonitor(device) },
                                    onDisconnect: { viewModel.disconnectHeartRateMonitor() }
                                )
                            }

                            if let error = viewModel.heartRateService.connectionError {
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
                        workout = viewModel.createWorkout()
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
                if let workout = workout {
                    WorkoutView(
                        viewModel: WorkoutViewModel(
                            workout: workout,
                            kickrService: viewModel.kickrService,
                            heartRateService: viewModel.heartRateService
                        ),
                        stravaService: viewModel.stravaService
                    )
                }
            }
        }
        .onAppear {
            viewModel.startScanning()
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
