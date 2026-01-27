import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showGraph = false
    @State private var chartScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

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
                .font(.headline)
            Button(action: {
                Task { await viewModel.connectToStrava() }
            }) {
                Text("Connect")
                    .font(.subheadline)
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
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadActivities() }
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.indoor.cycle")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No Zone 2 Workouts")
                .font(.subheadline)
            Button("Refresh") {
                Task { await viewModel.loadActivities() }
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
    }

    private var listView: some View {
        List {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(viewModel.formatDate(lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            }
            ForEach(viewModel.activities) { activity in
                CompactActivityRow(activity: activity, viewModel: viewModel)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshActivitiesFromPullDown()
        }
    }

    private var graphView: some View {
        VStack {
            // Filter activities that have both HR and power data
            let chartData = viewModel.activities.filter {
                $0.averageHeartrate != nil && $0.averageWatts != nil
            }.sorted { $0.startDate < $1.startDate }

            if chartData.isEmpty {
                Text("No activities with HR and power data")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let minPower = chartData.compactMap { $0.averageWatts }.min() ?? 100
                let maxPower = chartData.compactMap { $0.averageWatts }.max() ?? 200
                let minHR = (chartData.compactMap { $0.averageHeartrate }.min() ?? 100) - 5
                let maxHR = (chartData.compactMap { $0.averageHeartrate }.max() ?? 160) + 5
                let minDuration = Double(chartData.map { $0.movingTime }.min() ?? 1800)
                let maxDuration = Double(chartData.map { $0.movingTime }.max() ?? 7200)

                HStack(spacing: 0) {
                    // Sticky Y-axis
                    Chart(chartData) { activity in
                        PointMark(
                            x: .value("Date", activity.startDate),
                            y: .value("Avg HR", activity.averageHeartrate ?? 0)
                        )
                        .opacity(0)
                    }
                    .chartYScale(domain: minHR...maxHR)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let hr = value.as(Double.self) {
                                    Text("\(Int(hr))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(width: 35)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                    // Zoomable chart
                    GeometryReader { geometry in
                        let screenWidth = geometry.size.width
                        let baseWidth = max(screenWidth, CGFloat(chartData.count) * 40)
                        let chartWidth = baseWidth * chartScale

                        ScrollView(.horizontal, showsIndicators: false) {
                            Chart(chartData) { activity in
                                PointMark(
                                    x: .value("Date", activity.startDate),
                                    y: .value("Avg HR", activity.averageHeartrate ?? 0)
                                )
                                .foregroundStyle(powerColor(activity.averageWatts ?? 0, min: minPower, max: maxPower))
                                .symbolSize(durationSize(activity.movingTime, min: minDuration, max: maxDuration))
                            }
                            .chartYScale(domain: minHR...maxHR)
                            .chartXScale(range: .plotDimension(padding: 20))
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: max(4, Int(chartWidth / 80)))) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).year(.twoDigits), anchor: .top)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { _ in
                                    AxisGridLine()
                                }
                            }
                            .frame(width: chartWidth, height: geometry.size.height)
                            .padding(.horizontal, 8)
                            .scaleEffect(x: -1, anchor: .center)
                        }
                        .scaleEffect(x: -1, anchor: .center)
                    }
                }
                .frame(height: 220)
                .padding(.leading, 8)

                // Zoom controls
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            chartScale = max(1.0, chartScale / 1.15)
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title3)
                    }
                    .disabled(chartScale <= 1.01)

                    Text(String(format: "%.1fx", chartScale))
                        .font(.caption)
                        .frame(width: 35)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            chartScale = min(5.0, chartScale * 1.15)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title3)
                    }
                    .disabled(chartScale >= 5.0)
                }

                // Legend
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Color = Power:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Low")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 50, height: 8)
                            .cornerRadius(4)
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("High")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("Size = Duration:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Circle().fill(.gray).frame(width: 6, height: 6)
                        Text("Short")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Circle().fill(.gray).frame(width: 12, height: 12)
                        Text("Long")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
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

struct CompactActivityRow: View {
    let activity: StravaActivity
    let viewModel: HistoryViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Date and time
            Text(viewModel.formatDateWithTime(activity.startDate))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 105, alignment: .leading)

            // Stats - duration, power, HR
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.formatDuration(activity.movingTime))
                        .font(.caption)
                        .lineLimit(1)
                }
                .frame(width: 60, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(activity.averageWatts.map { "\(Int($0))" } ?? "-")
                        .font(.caption)
                }
                .frame(width: 40, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(activity.averageHeartrate.map { "\(Int($0))" } ?? "-")
                        .font(.caption)
                }
                .frame(width: 40, alignment: .leading)
            }

            Spacer()

            // Link to Strava
            Link(destination: URL(string: "https://www.strava.com/activities/\(activity.id)")!) {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel(stravaService: StravaService()))
}
