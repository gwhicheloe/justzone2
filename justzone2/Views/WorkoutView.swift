import SwiftUI
import Charts

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    let stravaService: StravaService
    @Binding var isPresented: Bool
    @State private var showSummary = false

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

            ScrollView {
                VStack(spacing: 20) {
                    // Main Metrics
                    HStack(spacing: 20) {
                        CompactMetricView(
                            icon: "heart.fill",
                            iconColor: .red,
                            value: viewModel.currentHeartRate > 0 ? "\(viewModel.currentHeartRate)" : "--",
                            unit: "BPM"
                        )

                        CompactMetricView(
                            icon: "bolt.fill",
                            iconColor: .blue,
                            value: viewModel.currentPower > 0 ? "\(viewModel.currentPower)" : "--",
                            unit: "W",
                            targetValue: viewModel.workout.targetPower
                        )
                    }
                    .padding(.top, 12)

                    // Time
                    VStack(spacing: 4) {
                        Text(viewModel.formatTime(viewModel.elapsedTime))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))

                        Text("Remaining: \(viewModel.formatTime(viewModel.remainingTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Chart
                    if !viewModel.chartData.isEmpty {
                        WorkoutChartView(
                            chartData: viewModel.chartData,
                            targetPower: viewModel.workout.targetPower
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }

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
            SummaryView(
                viewModel: SummaryViewModel(
                    workout: viewModel.workout,
                    stravaService: stravaService
                ),
                onDismiss: {
                    // Pop back to root
                    isPresented = false
                }
            )
        }
        .onAppear {
            if viewModel.state == .idle {
                // Small delay to ensure view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.startWorkout()
                }
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

struct CompactMetricView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let unit: String
    var targetValue: Int? = nil

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.caption)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let target = targetValue {
                Text("Target: \(target)W")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutChartView: View {
    let chartData: [ChartDataPoint]
    let targetPower: Int

    private var powerData: [(time: Double, value: Int)] {
        chartData.compactMap { point in
            guard let power = point.power else { return nil }
            return (time: point.time / 60, value: power)
        }
    }

    private var heartRateData: [(time: Double, value: Int)] {
        chartData.compactMap { point in
            guard let hr = point.heartRate else { return nil }
            return (time: point.time / 60, value: hr)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Progress")
                .font(.headline)

            Chart {
                // Target power line
                RuleMark(y: .value("Target", targetPower))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                // Power line - blue
                ForEach(Array(powerData.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value),
                        series: .value("Series", "Power")
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Heart rate line - red
                ForEach(Array(heartRateData.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value),
                        series: .value("Series", "HR")
                    )
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartYScale(domain: 0...max(maxValue, targetPower + 50))
            .chartXAxisLabel("Minutes")
            .chartLegend(.hidden)
            .frame(height: 120)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("Power").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("HR").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.green.opacity(0.5)).frame(width: 8, height: 8)
                    Text("Target").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var maxValue: Int {
        let maxPower = chartData.compactMap { $0.power }.max() ?? 0
        let maxHR = chartData.compactMap { $0.heartRate }.max() ?? 0
        return max(maxPower, maxHR)
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
            stravaService: StravaService(),
            isPresented: .constant(true)
        )
    }
}
