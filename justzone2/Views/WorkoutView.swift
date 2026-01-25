import SwiftUI

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    let stravaService: StravaService
    @State private var showSummary = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))

                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * viewModel.progress)
                }
            }
            .frame(height: 8)

            Spacer()

            // Main Metrics
            VStack(spacing: 40) {
                // Heart Rate
                MetricView(
                    icon: "heart.fill",
                    iconColor: .red,
                    value: viewModel.currentHeartRate > 0 ? "\(viewModel.currentHeartRate)" : "--",
                    unit: "BPM",
                    label: "Heart Rate"
                )

                // Power
                MetricView(
                    icon: "bolt.fill",
                    iconColor: .yellow,
                    value: viewModel.currentPower > 0 ? "\(viewModel.currentPower)" : "--",
                    unit: "W",
                    label: "Power",
                    targetValue: viewModel.workout.targetPower
                )

                // Time
                VStack(spacing: 4) {
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.system(size: 64, weight: .bold, design: .monospaced))

                    Text("Remaining: \(viewModel.formatTime(viewModel.remainingTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Controls
            HStack(spacing: 40) {
                if viewModel.state == .running {
                    Button(action: { viewModel.pauseWorkout() }) {
                        Image(systemName: "pause.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                } else if viewModel.state == .paused {
                    Button(action: { viewModel.resumeWorkout() }) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }

                Button(action: {
                    viewModel.stopWorkout()
                    showSummary = true
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(stateTitle)
                    .font(.headline)
            }
        }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(viewModel: SummaryViewModel(
                workout: viewModel.workout,
                stravaService: stravaService
            ))
        }
        .onAppear {
            if viewModel.state == .idle {
                viewModel.startWorkout()
            }
        }
        .onChange(of: viewModel.state) { newState in
            if newState == .completed {
                showSummary = true
            }
        }
    }

    private var stateTitle: String {
        switch viewModel.state {
        case .idle:
            return "Starting..."
        case .running:
            return "Zone 2 Workout"
        case .paused:
            return "Paused"
        case .completed:
            return "Complete"
        }
    }
}

struct MetricView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let unit: String
    let label: String
    var targetValue: Int? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(label)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            if let target = targetValue {
                Text("Target: \(target)W")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutView(
            viewModel: WorkoutViewModel(
                workout: Workout(targetPower: 150, targetDuration: 30 * 60),
                kickrService: KickrService(bluetoothManager: BluetoothManager()),
                heartRateService: HeartRateService(bluetoothManager: BluetoothManager())
            ),
            stravaService: StravaService()
        )
    }
}
