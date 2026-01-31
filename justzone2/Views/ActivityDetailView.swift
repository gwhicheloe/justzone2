import SwiftUI
import Charts

struct ActivityDetailView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var currentIndex: Int
    @State private var streams: ActivityStreams?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var activity: StravaActivity {
        viewModel.activities[currentIndex]
    }

    private var hasPrevious: Bool {
        currentIndex < viewModel.activities.count - 1
    }

    private var hasNext: Bool {
        currentIndex > 0
    }

    init(activityIndex: Int, viewModel: HistoryViewModel) {
        self.viewModel = viewModel
        self._currentIndex = State(initialValue: activityIndex)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Stats Grid
                statsGrid

                // Chart or loading/error state
                chartSection

                // Navigation arrows
                navigationControls

                // Strava Link
                stravaLinkButton
            }
            .padding()
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: currentIndex) {
            await loadStreams()
        }
    }

    private func goToPrevious() {
        guard hasPrevious else { return }
        currentIndex += 1
    }

    private func goToNext() {
        guard hasNext else { return }
        currentIndex -= 1
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(activity.name)
                .font(.headlineLarge)
                .multilineTextAlignment(.center)

            Text(viewModel.formatDate(activity.startDate))
                .font(.bodyMedium)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 20) {
            StatBox(
                icon: "clock",
                iconColor: .secondary,
                value: viewModel.formatDuration(activity.movingTime),
                label: "Duration"
            )

            StatBox(
                icon: "bolt.fill",
                iconColor: .blue,
                value: activity.averageWatts.map { "\(Int($0))" } ?? "--",
                label: "Avg Power"
            )

            StatBox(
                icon: "heart.fill",
                iconColor: .red,
                value: activity.averageHeartrate.map { "\(Int($0))" } ?? "--",
                label: "Avg HR"
            )
        }
    }

    // MARK: - Chart Section

    @ViewBuilder
    private var chartSection: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading stream data...")
                    .font(.labelMedium)
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.headlineLarge)
                    .foregroundColor(.secondary)
                Text(error)
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        } else if let streams = streams, streams.hasData {
            StreamChartView(streams: streams)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.headlineLarge)
                    .foregroundColor(.secondary)
                Text("No stream data available")
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Strava Link

    private var navigationControls: some View {
        HStack {
            Button {
                goToPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(!hasPrevious)

            Spacer()

            Text("\(viewModel.activities.count - currentIndex) of \(viewModel.activities.count)")
                .font(.labelMedium)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                goToNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(!hasNext)
        }
        .padding(.horizontal, 40)
    }

    private var stravaLinkButton: some View {
        Link(destination: URL(string: "https://www.strava.com/activities/\(activity.id)")!) {
            HStack {
                Image(systemName: "arrow.up.right.square")
                Text("View on Strava")
            }
            .font(.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.orange)
            .cornerRadius(8)
        }
        .padding(.top, 8)
    }

    // MARK: - Load Streams

    private func loadStreams() async {
        isLoading = true
        errorMessage = nil

        streams = await viewModel.loadStreams(for: activity)

        if streams == nil, let error = viewModel.streamsError {
            errorMessage = error
        }

        isLoading = false
    }
}

// MARK: - Stat Box Component

private struct StatBox: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.labelMedium)
                .foregroundColor(iconColor)

            Text(value)
                .font(.headlineMedium)

            Text(label)
                .font(.labelSmall)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Stream Chart View

private struct StreamChartView: View {
    let streams: ActivityStreams

    // Pre-computed chart data to avoid repeated calculations
    private let chartData: ChartData

    init(streams: ActivityStreams) {
        self.streams = streams
        self.chartData = ChartData(streams: streams)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Data")
                .font(.headlineSmall)

            HStack(spacing: 0) {
                // Left Y-axis labels (Power)
                if !chartData.powerData.isEmpty {
                    VStack {
                        Text("\(chartData.powerRange.upperBound)")
                        Spacer()
                        Text("\(chartData.powerRange.lowerBound)")
                    }
                    .font(.tiny)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                }

                // Chart area with overlaid charts
                ZStack {
                    // Power chart (left axis) - smoothed
                    if !chartData.powerData.isEmpty {
                        Chart {
                            ForEach(Array(chartData.powerData.enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Time", point.time),
                                    y: .value("Power", point.value)
                                )
                                .foregroundStyle(Color.blue)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                            }
                        }
                        .chartYScale(domain: chartData.powerRange)
                        .chartXScale(domain: 0...max(1, chartData.maxTime))
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks(position: .bottom) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let mins = value.as(Double.self) {
                                        Text("\(Int(mins))m")
                                            .font(.tiny)
                                    }
                                }
                            }
                        }
                    }

                    // Heart rate chart (right axis)
                    if !chartData.hrData.isEmpty {
                        Chart {
                            // Zone 2 HR band
                            RectangleMark(
                                xStart: .value("Start", 0),
                                xEnd: .value("End", max(1, chartData.maxTime)),
                                yStart: .value("Zone Min", chartData.zone2Min),
                                yEnd: .value("Zone Max", chartData.zone2Max)
                            )
                            .foregroundStyle(.green.opacity(0.2))

                            // HR data line
                            ForEach(Array(chartData.hrData.enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Time", point.time),
                                    y: .value("HR", point.value)
                                )
                                .foregroundStyle(Color.red)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                            }

                            // HR trend line (excluding cooldown)
                            ForEach(Array(chartData.trendLinePoints.enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Time", point.x),
                                    y: .value("HR", point.y),
                                    series: .value("Series", "trend")
                                )
                                .foregroundStyle(Color.black)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            }
                        }
                        .chartYScale(domain: chartData.hrRange)
                        .chartXScale(domain: 0...max(1, chartData.maxTime))
                        .chartYAxis(.hidden)
                        .chartXAxis(.hidden)
                    }
                }
                .frame(height: 180)

                // Right Y-axis labels (Heart Rate)
                if !chartData.hrData.isEmpty {
                    VStack {
                        Text("\(chartData.hrRange.upperBound)")
                        Spacer()
                        Text("\(chartData.hrRange.lowerBound)")
                    }
                    .font(.tiny)
                    .foregroundColor(.red)
                    .frame(width: 30)
                }
            }

            // Legend
            HStack(spacing: 12) {
                if !chartData.powerData.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Power")
                            .font(.labelSmall)
                            .foregroundColor(.secondary)
                    }
                }
                if !chartData.hrData.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("HR")
                            .font(.labelSmall)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.2)).frame(width: 12, height: 8)
                        Text("Zone 2")
                            .font(.labelSmall)
                            .foregroundColor(.secondary)
                    }
                    if !chartData.trendLinePoints.isEmpty {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.black)
                                .frame(width: 12, height: 2)
                            Text("HR Trend")
                                .font(.labelSmall)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Chart Data (computed once)

private struct ChartData {
    let powerData: [(time: Double, value: Int)]
    let hrData: [(time: Double, value: Int)]
    let trendLinePoints: [(x: Double, y: Double)]
    let powerRange: ClosedRange<Int>
    let hrRange: ClosedRange<Int>
    let maxTime: Double
    let zone2Min: Int
    let zone2Max: Int

    init(streams: ActivityStreams) {
        // Zone 2 settings
        let z2Min = UserDefaults.standard.integer(forKey: "zone2Min")
        let z2Max = UserDefaults.standard.integer(forKey: "zone2Max")
        let zone2MinVal = z2Min > 0 ? z2Min : 120
        let zone2MaxVal = z2Max > 0 ? z2Max : 140
        zone2Min = zone2MinVal
        zone2Max = zone2MaxVal

        // Find warmup end (when HR first enters Zone 2)
        let warmupEndIndex: Int
        if let heartrate = streams.heartrate {
            warmupEndIndex = heartrate.firstIndex { $0 >= zone2MinVal } ?? 0
        } else {
            warmupEndIndex = 0
        }

        // Find cooldown start (when rolling average power drops below threshold)
        var cooldownStartIndex: Int
        if let watts = streams.watts, watts.count > warmupEndIndex + 30 {
            // Calculate average power from middle portion
            let middleStart = warmupEndIndex + (watts.count - warmupEndIndex) / 4
            let middleEnd = warmupEndIndex + (watts.count - warmupEndIndex) * 3 / 4
            let middlePortion = Array(watts[middleStart..<middleEnd])
            let avgPower = middlePortion.isEmpty ? 100 : middlePortion.reduce(0, +) / middlePortion.count

            // Threshold: 60% of average power
            let threshold = avgPower * 6 / 10
            let windowSize = 10

            // Default to end of data
            cooldownStartIndex = watts.count - 1

            // Search forward from 70% mark, find first window where average drops below threshold
            let searchStart = warmupEndIndex + (watts.count - warmupEndIndex) * 7 / 10
            for i in searchStart..<(watts.count - windowSize) {
                let window = watts[i..<(i + windowSize)]
                let windowAvg = window.reduce(0, +) / windowSize
                if windowAvg < threshold {
                    // Cut just before this bad window starts
                    cooldownStartIndex = max(warmupEndIndex, i - 1)
                    break
                }
            }
        } else {
            cooldownStartIndex = streams.time.count - 1
        }

        // Ensure valid range
        cooldownStartIndex = max(cooldownStartIndex, warmupEndIndex)

        // Time offset so chart starts at 0
        let timeOffset: Double
        if warmupEndIndex < streams.time.count {
            timeOffset = Double(streams.time[warmupEndIndex]) / 60
        } else {
            timeOffset = 0
        }

        // Build smoothed power data (excluding warmup and cooldown)
        let computedPowerData: [(time: Double, value: Int)]
        if let watts = streams.watts, !watts.isEmpty, warmupEndIndex <= cooldownStartIndex {
            let windowSize = max(1, min(15, watts.count / 10))
            var smoothed: [Int] = []
            for i in 0..<watts.count {
                let start = max(0, i - windowSize / 2)
                let end = min(watts.count, i + windowSize / 2 + 1)
                let window = watts[start..<end]
                smoothed.append(window.reduce(0, +) / window.count)
            }
            let trimmedTime = Array(streams.time[warmupEndIndex...cooldownStartIndex])
            let trimmedSmoothed = Array(smoothed[warmupEndIndex...cooldownStartIndex])
            computedPowerData = zip(trimmedTime, trimmedSmoothed).map { (time: Double($0) / 60 - timeOffset, value: $1) }
        } else {
            computedPowerData = []
        }
        powerData = computedPowerData

        // Build HR data (excluding warmup and cooldown)
        let computedHRData: [(time: Double, value: Int)]
        if let heartrate = streams.heartrate, warmupEndIndex <= cooldownStartIndex, cooldownStartIndex < heartrate.count {
            let trimmedTime = Array(streams.time[warmupEndIndex...cooldownStartIndex])
            let trimmedHR = Array(heartrate[warmupEndIndex...cooldownStartIndex])
            computedHRData = zip(trimmedTime, trimmedHR).map { (time: Double($0) / 60 - timeOffset, value: $1) }
        } else {
            computedHRData = []
        }
        hrData = computedHRData

        // Compute ranges
        if !computedPowerData.isEmpty {
            let values = computedPowerData.map { $0.value }
            let minP = max(0, (values.min() ?? 100) - 20)
            let maxP = (values.max() ?? 200) + 20
            powerRange = minP...maxP
        } else {
            powerRange = 0...200
        }

        if !computedHRData.isEmpty {
            let values = computedHRData.map { $0.value }
            let minHR = max(0, (values.min() ?? 60) - 10)
            let maxHR = (values.max() ?? 180) + 10
            hrRange = minHR...maxHR
        } else {
            hrRange = 60...180
        }

        // Max time
        maxTime = computedHRData.last?.time ?? computedPowerData.last?.time ?? 1

        // Trend line (excluding last 10% for cooldown)
        if computedHRData.count >= 5 {
            let skipEnd = computedHRData.count / 10
            let endIndex = computedHRData.count - skipEnd
            let regressionData = computedHRData[0..<endIndex].map { (x: $0.time, y: Double($0.value)) }

            if regressionData.count >= 2 {
                let n = Double(regressionData.count)
                let sumX = regressionData.reduce(0) { $0 + $1.x }
                let sumY = regressionData.reduce(0) { $0 + $1.y }
                let sumXY = regressionData.reduce(0) { $0 + $1.x * $1.y }
                let sumX2 = regressionData.reduce(0) { $0 + $1.x * $1.x }
                let denominator = n * sumX2 - sumX * sumX

                if denominator != 0, let first = regressionData.first, let last = regressionData.last {
                    let slope = (n * sumXY - sumX * sumY) / denominator
                    let intercept = (sumY - slope * sumX) / n
                    trendLinePoints = [
                        (x: first.x, y: slope * first.x + intercept),
                        (x: last.x, y: slope * last.x + intercept)
                    ]
                } else {
                    trendLinePoints = []
                }
            } else {
                trendLinePoints = []
            }
        } else {
            trendLinePoints = []
        }
    }
}

// Preview requires activities in viewModel, skip for now
