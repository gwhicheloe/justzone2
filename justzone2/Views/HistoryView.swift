import SwiftUI
import Charts

enum HistoryViewMode: Int, CaseIterable {
    case list
    case bubbleChart
    case lineChart
}

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var viewMode: HistoryViewMode = .list
    @State private var zoomLevel: CGFloat = 1.0
    @State private var baseZoomLevel: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isStravaConnected {
                    connectPrompt
                } else if viewModel.isLoading && viewModel.activities.isEmpty {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.activities.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 0) {
                        // Toggle picker
                        Picker("View", selection: $viewMode) {
                            Image(systemName: "list.bullet").tag(HistoryViewMode.list)
                            Image(systemName: "chart.dots.scatter").tag(HistoryViewMode.bubbleChart)
                            Image(systemName: "chart.xyaxis.line").tag(HistoryViewMode.lineChart)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                        switch viewMode {
                        case .list:
                            listView
                        case .bubbleChart:
                            bubbleChartView
                        case .lineChart:
                            lineChartView
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.custom("ArialRoundedMTBold", size: 28))
                        .foregroundColor(.green)
                }
            }
            .onAppear {
                if viewModel.isStravaConnected && viewModel.activities.isEmpty {
                    Task { await viewModel.loadActivities() }
                }
            }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Connect to Strava")
                .font(.headlineSmall)
            Button(action: {
                Task { await viewModel.connectToStrava() }
            }) {
                Text("Connect")
                    .font(.bodyMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(viewModel.loadingProgress ?? "Loading...")
                .font(.labelMedium)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.headlineLarge)
                .foregroundColor(.red)
            Text(error)
                .font(.labelMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadActivities() }
            }
            .font(.labelMedium)
            .foregroundColor(.orange)
        }
        .padding()
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "figure.indoor.cycle")
                    .font(.headlineLarge)
                    .foregroundColor(.secondary)
                Text("No Zone 2 Workouts")
                    .font(.bodyMedium)
                Text("Pull down to refresh")
                    .font(.labelMedium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 100)
        }
        .refreshable {
            await viewModel.refreshActivitiesFromPullDown()
        }
    }

    private var listView: some View {
        List {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(viewModel.formatDate(lastUpdated))")
                    .font(.tiny)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
            ForEach(Array(viewModel.activities.enumerated()), id: \.element.id) { index, activity in
                NavigationLink(destination: ActivityDetailView(activityIndex: index, viewModel: viewModel)) {
                    CompactActivityRowContent(activity: activity, viewModel: viewModel)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshActivitiesFromPullDown()
        }
    }

    private var bubbleChartView: some View {
        let chartData = filterOutliers(viewModel.activities.filter {
            $0.averageHeartrate != nil && $0.averageWatts != nil
        }).sorted { $0.startDate < $1.startDate }

        return VStack(spacing: 12) {
            if chartData.isEmpty {
                Spacer()
                Text("No activities with HR and power data")
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                let minPower = chartData.compactMap { $0.averageWatts }.min() ?? 100
                let maxPower = chartData.compactMap { $0.averageWatts }.max() ?? 200
                let minHR = (chartData.compactMap { $0.averageHeartrate }.min() ?? 100) - 5
                let maxHR = (chartData.compactMap { $0.averageHeartrate }.max() ?? 160) + 5
                let minDuration = Double(chartData.map { $0.movingTime }.min() ?? 1800)
                let maxDuration = Double(chartData.map { $0.movingTime }.max() ?? 7200)

                // Calculate visible date range based on zoom level
                let dateRange = calculateDateRange(for: chartData)

                Chart(chartData) { activity in
                    PointMark(
                        x: .value("Date", activity.startDate),
                        y: .value("Avg HR", activity.averageHeartrate ?? 0)
                    )
                    .foregroundStyle(powerColor(activity.averageWatts ?? 0, min: minPower, max: maxPower))
                    .symbolSize(durationSize(activity.movingTime, min: minDuration, max: maxDuration))
                }
                .chartYScale(domain: minHR...maxHR)
                .chartXScale(domain: dateRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: dateAxisFormat, anchor: .top)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hr = value.as(Double.self) {
                                Text("\(Int(hr))")
                                    .font(.tiny)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)
                .contentShape(Rectangle())
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let newZoom = baseZoomLevel * value.magnification
                            withAnimation(.interactiveSpring) {
                                zoomLevel = max(1.0, min(newZoom, 15.0))
                            }
                        }
                        .onEnded { _ in
                            baseZoomLevel = zoomLevel
                        }
                )
                .animation(.smooth(duration: 0.3), value: zoomLevel)

                // Zoom controls
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            zoomLevel = max(1.0, zoomLevel / 1.5)
                            baseZoomLevel = zoomLevel
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.headlineMedium)
                    }
                    .disabled(zoomLevel <= 1.01)

                    Text(String(format: "%.1fx", zoomLevel))
                        .font(.labelMedium)
                        .monospacedDigit()
                        .frame(width: 40)

                    Button(action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            zoomLevel = min(15.0, zoomLevel * 1.5)
                            baseZoomLevel = zoomLevel
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.headlineMedium)
                    }
                    .disabled(zoomLevel >= 15.0)

                    Spacer()

                    if zoomLevel > 1.01 {
                        Button("Reset") {
                            withAnimation(.smooth(duration: 0.3)) {
                                zoomLevel = 1.0
                                baseZoomLevel = 1.0
                            }
                        }
                        .font(.labelMedium)
                        .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)

                // Legend
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Color = Power:")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Low")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                        LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 50, height: 8)
                            .cornerRadius(4)
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("High")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("Size = Duration:")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                        Circle().fill(.gray).frame(width: 6, height: 6)
                        Text("Short")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                        Circle().fill(.gray).frame(width: 12, height: 12)
                        Text("Long")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)

                Text("Pinch to zoom • Shows most recent when zoomed")
                    .font(.tiny)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
    }

    /// Date format for axis - shows year when viewing > 6 months of data
    private var dateAxisFormat: Date.FormatStyle {
        if zoomLevel < 2.0 {
            // Zoomed out - show month and year
            return .dateTime.month(.abbreviated).year(.twoDigits)
        } else {
            // Zoomed in - show day and month
            return .dateTime.day().month(.abbreviated)
        }
    }

    private func calculateDateRange(for chartData: [StravaActivity]) -> ClosedRange<Date> {
        let dates = chartData.map { $0.startDate }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            return Date()...Date()
        }

        let totalDuration = maxDate.timeIntervalSince(minDate)

        // Add padding (5% or at least 1 day) to prevent dot clipping at edges
        let padding = max(totalDuration * 0.05, 86400)

        // Calculate visible duration based on zoom level
        let visibleDuration = totalDuration / zoomLevel

        // Anchor to right (most recent data stays visible)
        // As zoom increases, left boundary moves right
        let visibleMinDate = maxDate.addingTimeInterval(-visibleDuration)

        return visibleMinDate.addingTimeInterval(-padding)...maxDate.addingTimeInterval(padding)
    }

    private func durationSize(_ duration: Int, min: Double, max: Double) -> CGFloat {
        guard max > min else { return 100 }
        let normalized = (Double(duration) - min) / (max - min)
        // Size from 50 to 200
        return 50 + normalized * 150
    }

    private func powerColor(_ power: Double, min: Double, max: Double) -> Color {
        guard max > min else { return .yellow }
        let normalized = (power - min) / (max - min)
        // Green (low power) -> Yellow -> Red (high power)
        if normalized < 0.5 {
            return Color(red: normalized * 2, green: 1, blue: 0)
        } else {
            return Color(red: 1, green: 1 - (normalized - 0.5) * 2, blue: 0)
        }
    }

    /// Filter out obvious outliers (values below 75% of median)
    private func filterOutliers(_ activities: [StravaActivity]) -> [StravaActivity] {
        guard activities.count >= 3 else { return activities }

        // Calculate medians
        let powers = activities.compactMap { $0.averageWatts }.sorted()
        let hrs = activities.compactMap { $0.averageHeartrate }.sorted()

        guard !powers.isEmpty, !hrs.isEmpty else { return activities }

        let medianPower = powers[powers.count / 2]
        let medianHR = hrs[hrs.count / 2]

        // Filter out activities outside 75%-125% of median
        let powerLowThreshold = medianPower * 0.75
        let powerHighThreshold = medianPower * 1.25
        let hrLowThreshold = medianHR * 0.75
        let hrHighThreshold = medianHR * 1.25

        return activities.filter { activity in
            guard let power = activity.averageWatts, let hr = activity.averageHeartrate else {
                return false
            }
            return power >= powerLowThreshold && power <= powerHighThreshold &&
                   hr >= hrLowThreshold && hr <= hrHighThreshold
        }
    }

    // MARK: - Line Chart View

    private var lineChartView: some View {
        let chartData = filterOutliers(viewModel.activities.filter {
            $0.averageHeartrate != nil && $0.averageWatts != nil
        }).sorted { $0.startDate < $1.startDate }

        return VStack(spacing: 12) {
            if chartData.isEmpty {
                Spacer()
                Text("No activities with HR and power data")
                    .font(.bodyMedium)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                // Use 5th and 95th percentile for Y-axis to avoid outliers stretching the chart
                let sortedHR = chartData.compactMap { $0.averageHeartrate }.sorted()
                let sortedPower = chartData.compactMap { $0.averageWatts }.sorted()

                let hrP5 = sortedHR.isEmpty ? 100.0 : sortedHR[max(0, sortedHR.count / 20)]
                let hrP95 = sortedHR.isEmpty ? 160.0 : sortedHR[min(sortedHR.count - 1, sortedHR.count * 19 / 20)]
                let powerP5 = sortedPower.isEmpty ? 100.0 : sortedPower[max(0, sortedPower.count / 20)]
                let powerP95 = sortedPower.isEmpty ? 200.0 : sortedPower[min(sortedPower.count - 1, sortedPower.count * 19 / 20)]

                let minHR = hrP5 - 5
                let maxHR = hrP95 + 5
                let minPower = powerP5 - 10
                let maxPower = powerP95 + 10

                // Zone 2 HR range from settings
                let z2Min = UserDefaults.standard.integer(forKey: "zone2Min")
                let z2Max = UserDefaults.standard.integer(forKey: "zone2Max")
                let zone2Min = z2Min > 0 ? z2Min : 120
                let zone2Max = z2Max > 0 ? z2Max : 140

                // Build line segments (break if gap > 2 weeks)
                let twoWeeks: TimeInterval = 14 * 24 * 60 * 60
                let hrSegments = buildLineSegments(from: chartData, getValue: { $0.averageHeartrate ?? 0 }, maxGap: twoWeeks)
                let powerSegments = buildLineSegments(from: chartData, getValue: { $0.averageWatts ?? 0 }, maxGap: twoWeeks)

                // Calculate visible date range based on zoom level
                let dateRange = calculateDateRange(for: chartData)

                let midPower = (minPower + maxPower) / 2
                let midHR = (minHR + maxHR) / 2

                HStack(spacing: 0) {
                    // Left Y-axis (Power)
                    VStack {
                        Text("\(Int(maxPower))")
                        Spacer()
                        Text("\(Int(midPower))")
                        Spacer()
                        Text("\(Int(minPower))")
                    }
                    .font(.tiny)
                    .foregroundColor(.blue)
                    .frame(width: 30, height: 220)

                    ZStack {
                        // Power lines (blue)
                        Chart {
                            ForEach(Array(powerSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                                ForEach(Array(segment.enumerated()), id: \.offset) { pointIndex, point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Power", point.value),
                                        series: .value("Segment", "power-\(segmentIndex)")
                                    )
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                            }
                        }
                        .chartYScale(domain: minPower...maxPower)
                        .chartXScale(domain: dateRange)
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: dateAxisFormat, anchor: .top)
                            }
                        }

                        // HR lines (red) with Zone 2 band
                        Chart {
                            // Zone 2 band
                            RectangleMark(
                                yStart: .value("Zone Min", zone2Min),
                                yEnd: .value("Zone Max", zone2Max)
                            )
                            .foregroundStyle(.green.opacity(0.2))

                            // HR data lines
                            ForEach(Array(hrSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                                ForEach(Array(segment.enumerated()), id: \.offset) { pointIndex, point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("HR", point.value),
                                        series: .value("Segment", "hr-\(segmentIndex)")
                                    )
                                    .foregroundStyle(Color.red)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                            }
                        }
                        .chartYScale(domain: minHR...maxHR)
                        .chartXScale(domain: dateRange)
                        .chartYAxis(.hidden)
                        .chartXAxis(.hidden)
                    }
                    .frame(height: 220)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let newZoom = baseZoomLevel * value.magnification
                                withAnimation(.interactiveSpring) {
                                    zoomLevel = max(1.0, min(newZoom, 15.0))
                                }
                            }
                            .onEnded { _ in
                                baseZoomLevel = zoomLevel
                            }
                    )
                    .animation(.smooth(duration: 0.3), value: zoomLevel)

                    // Right Y-axis (HR)
                    VStack {
                        Text("\(Int(maxHR))")
                        Spacer()
                        Text("\(Int(midHR))")
                        Spacer()
                        Text("\(Int(minHR))")
                    }
                    .font(.tiny)
                    .foregroundColor(.red)
                    .frame(width: 30, height: 220)
                }
                .padding(.horizontal)

                // Zoom controls
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            zoomLevel = max(1.0, zoomLevel / 1.5)
                            baseZoomLevel = zoomLevel
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.headlineMedium)
                    }
                    .disabled(zoomLevel <= 1.01)

                    Text(String(format: "%.1fx", zoomLevel))
                        .font(.labelMedium)
                        .monospacedDigit()
                        .frame(width: 40)

                    Button(action: {
                        withAnimation(.smooth(duration: 0.3)) {
                            zoomLevel = min(15.0, zoomLevel * 1.5)
                            baseZoomLevel = zoomLevel
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.headlineMedium)
                    }
                    .disabled(zoomLevel >= 15.0)

                    Spacer()

                    if zoomLevel > 1.01 {
                        Button("Reset") {
                            withAnimation(.smooth(duration: 0.3)) {
                                zoomLevel = 1.0
                                baseZoomLevel = 1.0
                            }
                        }
                        .font(.labelMedium)
                        .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(Color.blue).frame(width: 16, height: 3)
                        Text("Avg Power")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(Color.red).frame(width: 16, height: 3)
                        Text("Avg HR")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)

                Text("Pinch to zoom • Lines break after 2+ week gaps")
                    .font(.tiny)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
    }

    private func buildLineSegments(from activities: [StravaActivity], getValue: (StravaActivity) -> Double, maxGap: TimeInterval) -> [[(date: Date, value: Double)]] {
        var segments: [[(date: Date, value: Double)]] = []
        var currentSegment: [(date: Date, value: Double)] = []

        for activity in activities {
            let point = (date: activity.startDate, value: getValue(activity))

            if let lastPoint = currentSegment.last {
                let gap = activity.startDate.timeIntervalSince(lastPoint.date)
                if gap > maxGap {
                    // Gap too large, start new segment
                    if !currentSegment.isEmpty {
                        segments.append(currentSegment)
                    }
                    currentSegment = [point]
                } else {
                    currentSegment.append(point)
                }
            } else {
                currentSegment.append(point)
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }
}

struct CompactActivityRowContent: View {
    let activity: StravaActivity
    let viewModel: HistoryViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Date and time
            Text(viewModel.formatDateWithTime(activity.startDate))
                .font(.labelMedium)
                .frame(width: 105, alignment: .leading)

            // Stats - duration, power, HR
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.tiny)
                        .foregroundColor(.secondary)
                    Text(viewModel.formatDuration(activity.movingTime))
                        .font(.labelMedium)
                        .lineLimit(1)
                }
                .frame(width: 60, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.tiny)
                        .foregroundColor(.blue)
                    Text(activity.averageWatts.map { "\(Int($0))" } ?? "-")
                        .font(.labelMedium)
                }
                .frame(width: 40, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.tiny)
                        .foregroundColor(.red)
                    Text(activity.averageHeartrate.map { "\(Int($0))" } ?? "-")
                        .font(.labelMedium)
                }
                .frame(width: 40, alignment: .leading)
            }

            Spacer()
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel(stravaService: StravaService()))
}
