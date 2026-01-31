import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showGraph = false
    @State private var zoomLevel: CGFloat = 1.0
    @State private var baseZoomLevel: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isStravaConnected {
                    connectPrompt
                } else if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.activities.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 0) {
                        // Toggle picker
                        Picker("View", selection: $showGraph) {
                            Image(systemName: "list.bullet").tag(false)
                            Image(systemName: "chart.xyaxis.line").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .padding(.vertical, 8)

                        if showGraph {
                            graphView
                        } else {
                            listView
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if viewModel.isStravaConnected && !viewModel.isLoading {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task { await viewModel.refreshActivities() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
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
            Text("Loading...")
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
        VStack(spacing: 12) {
            Image(systemName: "figure.indoor.cycle")
                .font(.headlineLarge)
                .foregroundColor(.secondary)
            Text("No Zone 2 Workouts")
                .font(.bodyMedium)
            Button("Refresh") {
                Task { await viewModel.loadActivities() }
            }
            .font(.labelMedium)
            .foregroundColor(.orange)
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

    private var graphView: some View {
        let chartData = viewModel.activities.filter {
            $0.averageHeartrate != nil && $0.averageWatts != nil
        }.sorted { $0.startDate < $1.startDate }

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
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), anchor: .top)
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
                                zoomLevel = max(1.0, min(newZoom, 10.0))
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
                            zoomLevel = min(10.0, zoomLevel * 1.5)
                            baseZoomLevel = zoomLevel
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.headlineMedium)
                    }
                    .disabled(zoomLevel >= 10.0)

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

            // Chevron indicator for navigation
            Image(systemName: "chevron.right")
                .font(.labelSmall)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel(stravaService: StravaService()))
}
