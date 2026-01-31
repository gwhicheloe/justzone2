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
                            .font(.displayMedium)
                            .monospacedDigit()

                        Text("Remaining: \(viewModel.formatTime(viewModel.remainingTime))")
                            .font(.bodyMedium)
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
                    .font(.headlineSmall)
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
        .onChange(of: viewModel.state) { oldState, newState in
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
                    .font(.labelMedium)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.displaySmall)
                Text(unit)
                    .font(.labelMedium)
                    .foregroundColor(.secondary)
            }

            if let target = targetValue {
                Text("Target: \(target)W")
                    .font(.labelSmall)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutChartView: View {
    let chartData: [ChartDataPoint]
    let targetPower: Int

    // Zone 2 HR settings from UserDefaults
    private var zone2Min: Int {
        let value = UserDefaults.standard.integer(forKey: "zone2Min")
        return value > 0 ? value : 120
    }

    private var zone2Max: Int {
        let value = UserDefaults.standard.integer(forKey: "zone2Max")
        return value > 0 ? value : 140
    }

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

    private var powerRange: ClosedRange<Int> {
        let minP = max(0, (chartData.compactMap { $0.power }.min() ?? 100) - 20)
        let maxP = max(chartData.compactMap { $0.power }.max() ?? 200, targetPower) + 20
        return minP...maxP
    }

    private var hrRange: ClosedRange<Int> {
        let minHR = max(0, (chartData.compactMap { $0.heartRate }.min() ?? 60) - 10)
        let maxHR = (chartData.compactMap { $0.heartRate }.max() ?? 180) + 10
        return minHR...maxHR
    }

    private var maxTime: Double {
        (chartData.map { $0.time }.max() ?? 60) / 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Progress")
                .font(.headlineSmall)

            HStack(spacing: 0) {
                // Left Y-axis labels (Power)
                VStack {
                    Text("\(powerRange.upperBound)")
                    Spacer()
                    Text("\(powerRange.lowerBound)")
                }
                .font(.tiny)
                .foregroundColor(.blue)
                .frame(width: 30)

                // Chart area with overlaid charts
                ZStack {
                    // Power chart (left axis)
                    Chart {
                        // Target power line
                        RuleMark(y: .value("Target", targetPower))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                        ForEach(Array(powerData.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("Power", point.value)
                            )
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYScale(domain: powerRange)
                    .chartXScale(domain: 0...max(1, maxTime))
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(position: .bottom)
                    }

                    // Heart rate chart (right axis)
                    Chart {
                        // Zone 2 HR band
                        RectangleMark(
                            xStart: .value("Start", 0),
                            xEnd: .value("End", max(1, maxTime)),
                            yStart: .value("Zone Min", zone2Min),
                            yEnd: .value("Zone Max", zone2Max)
                        )
                        .foregroundStyle(.green.opacity(0.2))

                        ForEach(Array(heartRateData.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("HR", point.value)
                            )
                            .foregroundStyle(Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYScale(domain: hrRange)
                    .chartXScale(domain: 0...max(1, maxTime))
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                }
                .frame(height: 120)

                // Right Y-axis labels (Heart Rate)
                VStack {
                    Text("\(hrRange.upperBound)")
                    Spacer()
                    Text("\(hrRange.lowerBound)")
                }
                .font(.tiny)
                .foregroundColor(.red)
                .frame(width: 30)
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("Power (W)")
                        .font(.labelSmall)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("HR (bpm)")
                        .font(.labelSmall)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.green.opacity(0.5)).frame(width: 8, height: 8)
                    Text("Target")
                        .font(.labelSmall)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.2)).frame(width: 12, height: 8)
                    Text("Zone 2")
                        .font(.labelSmall)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WorkoutView(
            viewModel: WorkoutViewModel(
                workout: Workout(targetPower: 150, targetDuration: 30 * 60),
                kickrService: KickrService(bluetoothManager: BluetoothManager()),
                heartRateService: HeartRateService(bluetoothManager: BluetoothManager()),
                healthKitManager: HealthKitManager(),
                liveActivityManager: LiveActivityManager()
            ),
            stravaService: StravaService(),
            isPresented: .constant(true)
        )
    }
}
