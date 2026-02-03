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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Activity")
                    .font(.custom("ArialRoundedMTBold", size: 28))
                    .foregroundColor(.green)
            }
        }
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
                                .foregroundStyle(Color.primary)
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
                                .fill(Color.primary)
                                .frame(width: 12, height: 2)
                            Text("HR Trend")
                                .font(.labelSmall)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Analytics
            if chartData.timeInZonePercent != nil || chartData.hrDriftPerHour != nil {
                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 24) {
                    if let timeInZone = chartData.timeInZonePercent {
                        VStack(spacing: 2) {
                            Text("\(timeInZone)%")
                                .font(.headlineMedium)
                                .foregroundColor(timeInZone >= 80 ? .green : (timeInZone >= 60 ? .orange : .red))
                            Text("Time in Zone")
                                .font(.labelSmall)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let drift = chartData.hrDriftPerHour {
                        VStack(spacing: 2) {
                            Text(String(format: "%+.1f", drift))
                                .font(.headlineMedium)
                                .foregroundColor(abs(drift) <= 5 ? .green : (abs(drift) <= 10 ? .orange : .red))
                            Text("HR Drift/hr")
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
    let timeInZonePercent: Int?      // Percentage of time HR was in Zone 2
    let hrDriftPerHour: Double?      // HR trend slope in bpm per hour

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

        // Find cooldown start using backward search with heavily smoothed data
        // This approach finds where the main workout ENDS rather than where cooldown STARTS
        var cooldownStartIndex: Int
        if let watts = streams.watts, watts.count > warmupEndIndex + 60 {
            // Create heavily smoothed power data for detection (~30 second window)
            // This eliminates noise and brief dips that could confuse detection
            let smoothWindowSize = min(30, max(10, watts.count / 20))
            var smoothedForDetection: [Int] = []
            for i in 0..<watts.count {
                let halfWindow = smoothWindowSize / 2
                let start = max(0, i - halfWindow)
                let end = min(watts.count, i + halfWindow + 1)
                let window = watts[start..<end]
                smoothedForDetection.append(window.reduce(0, +) / window.count)
            }

            // Calculate baseline average from middle 50% (most reliable portion)
            let middleStart = warmupEndIndex + (watts.count - warmupEndIndex) / 4
            let middleEnd = warmupEndIndex + (watts.count - warmupEndIndex) * 3 / 4
            let middlePortion = Array(smoothedForDetection[middleStart..<middleEnd])
            let avgPower = middlePortion.isEmpty ? 100 : middlePortion.reduce(0, +) / middlePortion.count

            // Higher threshold: 75% of average (more aggressive than previous 60%)
            let threshold = avgPower * 75 / 100

            // Window size for checking sustained power (prevents false positives from brief spikes)
            let checkWindowSize = min(20, max(5, watts.count / 30))

            // Default to end of data
            cooldownStartIndex = watts.count - 1

            // Search BACKWARD from end to find last point with sustained normal power
            // This naturally skips past zeros/cliffs at the end
            for i in stride(from: watts.count - checkWindowSize - 1, through: warmupEndIndex, by: -1) {
                let windowEnd = i + checkWindowSize
                let window = smoothedForDetection[i..<windowEnd]
                let windowAvg = window.reduce(0, +) / checkWindowSize

                if windowAvg >= threshold {
                    // Found sustained normal power - end chart at START of this window
                    // Then subtract additional buffer to ensure we're well clear of any decline
                    let safetyBuffer = smoothWindowSize  // Extra margin for display smoothing
                    cooldownStartIndex = max(warmupEndIndex, i - safetyBuffer)
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
        // Use very aggressive smoothing (~2 minute window) for an almost flat line
        // Zone 2 power should be steady, so heavy smoothing reveals the true trend
        let computedPowerData: [(time: Double, value: Int)]
        if let watts = streams.watts, !watts.isEmpty, warmupEndIndex <= cooldownStartIndex {
            let windowSize = max(30, min(120, watts.count / 10))
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
        var computedSlope: Double?
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
                    computedSlope = slope
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

        // Calculate time in zone percentage
        if !computedHRData.isEmpty {
            let inZoneCount = computedHRData.filter { $0.value >= zone2MinVal && $0.value <= zone2MaxVal }.count
            timeInZonePercent = (inZoneCount * 100) / computedHRData.count
        } else {
            timeInZonePercent = nil
        }

        // Calculate HR drift per hour (slope is in bpm per minute, convert to per hour)
        if let slope = computedSlope {
            hrDriftPerHour = slope * 60
        } else {
            hrDriftPerHour = nil
        }
    }
}

// Preview requires activities in viewModel, skip for now
