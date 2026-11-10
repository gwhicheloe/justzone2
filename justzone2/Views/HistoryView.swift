import SwiftUI
import Charts
import UIKit

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
    @State private var isLandscape = false
    /// Show the normalised trend (power at the Zone 2 target heart rate).
    /// The trend chart shows Zone 2 power by default once it's available; a
    /// rider who switches it off is remembered. (History still opens on the list.)
    @AppStorage("historyNormalised") private var normalisedOn = true

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Group {
                    if !viewModel.isStravaConnected && viewModel.localWorkouts.isEmpty && viewModel.activities.isEmpty {
                        connectPrompt
                    } else if viewModel.isLoading && viewModel.activities.isEmpty {
                        loadingView
                    } else if let error = viewModel.error {
                        errorView(error)
                    } else if viewModel.activities.isEmpty && viewModel.localWorkouts.isEmpty {
                        emptyView
                    } else {
                        VStack(spacing: 0) {
                            // Larger symbols: a segmented control ignores font size, so
                            // the images are pre-rendered at a bigger point size.
                            Picker("View", selection: $viewMode) {
                                Self.switcherIcon("list.bullet").tag(HistoryViewMode.list)
                                Self.switcherIcon("chart.dots.scatter").tag(HistoryViewMode.bubbleChart)
                                // The trend chart carries a small green "Z2P" once Zone 2 power
                                // is available: our mark for that view.
                                Self.switcherIcon("chart.xyaxis.line", badge: viewModel.normalised.isReady ? "Z2P" : nil).tag(HistoryViewMode.lineChart)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 230)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                            switch viewMode {
                            case .list:
                                listView
                            case .bubbleChart:
                                bubbleChartView
                                    .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
                            case .lineChart:
                                lineChartView
                                    .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
                            }
                        }
                    }
                }
                .onChange(of: geometry.size) { _, size in
                    isLandscape = size.width > size.height
                }
                .onChange(of: viewMode) { _, newMode in
                    updateOrientationLock(for: newMode)
                }
                .onAppear {
                    isLandscape = geometry.size.width > geometry.size.height
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isLandscape {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Text("History")
                                .font(.custom("ArialRoundedMTBold", size: 28))
                                .foregroundColor(.green)
                            DemoTitleTag()
                        }
                    }
                }
            }
            .onAppear {
                if viewModel.isStravaConnected && viewModel.activities.isEmpty {
                    Task { await viewModel.loadActivities() }
                }
                viewModel.loadLocalWorkouts()
                updateOrientationLock(for: viewMode)
            }
        }
        .onDisappear {
            forcePortrait()
        }
        .alert("Strava",
               isPresented: Binding(
                   get: { viewModel.stravaError != nil },
                   set: { if !$0 { viewModel.stravaError = nil } }
               ),
               actions: { Button("OK", role: .cancel) { viewModel.stravaError = nil } },
               message: { Text(viewModel.stravaError ?? "") })
    }

    private func updateOrientationLock(for mode: HistoryViewMode) {
        switch mode {
        case .list:
            forcePortrait()
        case .bubbleChart, .lineChart:
            AppDelegate.orientationLock = .allButUpsideDown
            // Trigger iOS to re-query application(_:supportedInterfaceOrientationsFor:)
            // same mechanism that fires automatically on NavigationLink push/pop
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .forEach { $0.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
    }

    private func forcePortrait() {
        AppDelegate.orientationLock = .portrait
        UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .forEach { $0.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }


    /// Shown when there's nothing to display yet. Strava is strictly optional —
    /// it only *imports* past rides. Workouts recorded in the app land here on
    /// their own, so this must never read as a sign-in wall: an App Review
    /// tester followed the Strava button off to a third-party signup page,
    /// hit an error there, and reported the app as inaccessible.
    private var connectPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "figure.indoor.cycle")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("No workouts yet")
                .font(.headlineSmall)
            Text("Rides you record in JustZone2 appear here automatically — no account needed.")
                .font(.labelMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Want to try it without a trainer? Turn on Demo Mode in Settings.")
                .font(.labelSmall)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 2)

            VStack(spacing: 8) {
                Text("Already ride with Strava?")
                    .font(.labelSmall)
                    .foregroundColor(.secondary)
                Button(action: {
                    Task { await viewModel.connectToStrava() }
                }) {
                    Image("btn_strava_connect_orange")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                }
                Text("Optional — imports your past Zone 2 rides.")
                    .font(.labelSmall)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .readableWidth()
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
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.headlineLarge)
                    .foregroundColor(.red)
                Text(error)
                    .font(.labelMedium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.refreshActivities() }
                }
                .font(.labelMedium)
                .foregroundColor(.strava)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 100)
        }
        .refreshable {
            await viewModel.refreshActivities()
        }
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
            if !viewModel.localWorkouts.isEmpty {
                Section {
                    ForEach(viewModel.localWorkouts) { local in
                        NavigationLink(destination: LocalActivityDetailView(local: local, viewModel: viewModel)) {
                            LocalWorkoutRow(local: local, viewModel: viewModel)
                        }
                    }
                } header: {
                    // Strava is optional. Without it these are simply the
                    // rider's rides, not a backlog of failed uploads.
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isStravaConnected ? "icloud.slash" : "figure.indoor.cycle")
                            .font(.tiny)
                        Text(viewModel.isStravaConnected ? "Pending Upload" : "Your Rides")
                            .font(.tiny)
                    }
                    .foregroundColor(.secondary)
                }
            }

            if viewModel.lastUpdated != nil || viewModel.isStravaConnected || !viewModel.normalised.completeIDs.isEmpty {
                VStack(spacing: 2) {
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Updated \(viewModel.formatDate(lastUpdated))")
                    }
                    // Legend for the per-ride download marker.
                    if viewModel.isStravaConnected || !viewModel.normalised.completeIDs.isEmpty {
                        HStack(spacing: 12) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.circle.fill").foregroundColor(.green)
                                Text("downloaded")
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.circle").foregroundColor(.secondary.opacity(0.5))
                                Text("to download")
                            }
                        }
                    }
                }
                .font(.tiny)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
            }
            ForEach(Array(viewModel.activities.enumerated()), id: \.element.id) { index, activity in
                NavigationLink(destination: ActivityDetailView(activityIndex: index, viewModel: viewModel)) {
                    CompactActivityRowContent(activity: activity, viewModel: viewModel,
                                              hasFullData: viewModel.normalised.completeIDs.contains(activity.id),
                                              isDownloading: viewModel.normalised.downloadingID == activity.id)
                }
            }
        }
        .listStyle(.plain)
        .readableWidth()
        .refreshable {
            viewModel.loadLocalWorkouts()
            await viewModel.refreshActivitiesFromPullDown()
        }
    }

    private var bubbleChartView: some View {
        let chartData = filterOutliers(viewModel.chartActivities.filter {
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

                // Calculate visible date range based on zoom level
                let dateRange = calculateDateRange(for: chartData)

                Chart(chartData) { activity in
                    PointMark(
                        x: .value("Date", activity.startDate),
                        y: .value("Avg HR", activity.averageHeartrate ?? 0)
                    )
                    .foregroundStyle(powerColor(activity.averageWatts ?? 0, min: minPower, max: maxPower))
                    .symbolSize(Self.durationArea(activity.movingTime))
                }
                .chartYScale(domain: minHR...maxHR)
                .chartXScale(domain: dateRange)
                .chartXAxis {
                    AxisMarks(values: axisDates(for: dateRange)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: dateAxis(for: dateRange).format, anchor: .top)
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
                        .foregroundColor(.strava)
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
                    HStack(spacing: 8) {
                        Text("Size = Duration:")
                            .font(.tiny)
                            .foregroundColor(.secondary)
                        durationKey(30, "30 min")
                        durationKey(60, "1 h")
                        durationKey(120, "2 h")
                    }
                }
                .padding(.top, 4)


                Spacer()
            }
        }
    }

    /// Date-axis ticks for the visible range. Labels are placed at a regular
    /// stride and formatted to suit how much time is on screen. The old version
    /// chose the format by zoom level alone and let the chart place ~5 labels
    /// freely, so a 12-week history read "Jul 26, Jul 26, Aug 26, Aug 26…" —
    /// repeated labels that also looked like "26 July" rather than July 2026.
    private func dateAxis(for range: ClosedRange<Date>) -> (unit: Calendar.Component, count: Int, format: Date.FormatStyle) {
        let days = range.upperBound.timeIntervalSince(range.lowerBound) / 86_400
        switch days {
        case ..<36:  return (.weekOfYear, 1, .dateTime.day().month(.abbreviated))    // "7 Jul"
        case ..<75:  return (.weekOfYear, 2, .dateTime.day().month(.abbreviated))
        case ..<155: return (.weekOfYear, 3, .dateTime.day().month(.abbreviated))
        case ..<280: return (.month, 1, .dateTime.month(.abbreviated))               // "Jul"
        case ..<550: return (.month, 2, .dateTime.month(.abbreviated))
        case ..<1100: return (.month, 6, .dateTime.month(.abbreviated).year())      // "Jul 2026"
        default:     return (.year, 1, .dateTime.year())                            // "2026": several years of history
        }
    }

    /// The label dates for the visible range: one every `count` units, skipping
    /// any too close to either edge — a label centred on the edge gets clipped
    /// (a stray "2" of "21 Sep" at the right-hand end).
    private func axisDates(for range: ClosedRange<Date>) -> [Date] {
        let spec = dateAxis(for: range), cal = Calendar.current
        let span = range.upperBound.timeIntervalSince(range.lowerBound), margin = span * 0.06
        let startUnit: Calendar.Component = spec.unit == .weekOfYear ? .weekOfYear : (spec.unit == .year ? .year : .month)
        guard var d = cal.dateInterval(of: startUnit, for: range.lowerBound)?.start else { return [] }
        var out: [Date] = []
        while d <= range.upperBound {
            if d >= range.lowerBound.addingTimeInterval(margin) && d <= range.upperBound.addingTimeInterval(-margin) { out.append(d) }
            guard let next = cal.date(byAdding: spec.unit, value: spec.count, to: d) else { break }
            d = next
        }
        return out
    }

    private func calculateDateRange(for chartData: [StravaActivity]) -> ClosedRange<Date> {
        calculateDateRange(dates: chartData.map { $0.startDate })
    }

    private func calculateDateRange(dates: [Date]) -> ClosedRange<Date> {
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

    /// Bubble area (square points) for a ride of `seconds`. Area is
    /// proportional to duration on a fixed scale (2.5 pt² per minute), so a
    /// 2-hour ride has twice the area of a 1-hour ride whatever else is on
    /// the chart. The old version scaled between the shortest and longest
    /// ride shown, over a narrow 50–200 range: one long outdoor ride squashed
    /// every normal session to almost the same size. Clamped so a very short
    /// ride stays visible and a very long one doesn't swamp the chart.
    static func durationArea(_ seconds: Int) -> CGFloat {
        let minutes = Double(seconds) / 60
        return CGFloat(min(max(minutes * 2.5, 25), 450))
    }

    /// Legend circle matching a bubble of the given duration.
    private func durationKey(_ minutes: Int, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(.gray)
                .frame(width: sqrt(Self.durationArea(minutes * 60)), height: sqrt(Self.durationArea(minutes * 60)))
            Text(label)
                .font(.tiny)
                .foregroundColor(.secondary)
        }
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
        VStack(spacing: 6) {
            normalisedControl
            if showNormalised {
                normalisedChart
            } else {
                rawTrendChart
            }
        }
    }

    // MARK: - Normalised trend (power at the Zone 2 target heart rate)

    private var showNormalised: Bool { normalisedOn && viewModel.normalised.isReady }

    /// A view-switcher symbol rendered at a larger size than the segmented
    /// control's default.
    static func switcherIcon(_ name: String, badge: String? = nil) -> Image {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        guard let symbol = UIImage(systemName: name, withConfiguration: config) else { return Image(systemName: name) }
        guard let badge else { return Image(uiImage: symbol) }

        // Symbol plus a small green superscript, drawn as one image (a
        // segmented control can't hold anything else). Drawn in its real
        // colours, so the symbol is white to match the others (the app is dark).
        let font = UIFont.systemFont(ofSize: 9, weight: .heavy).rounded
        let text = NSAttributedString(string: badge, attributes: [.font: font, .foregroundColor: UIColor.systemGreen])
        let ts = text.size()
        let size = CGSize(width: symbol.size.width + ts.width * 0.75, height: symbol.size.height + ts.height * 0.35)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(at: CGPoint(x: 0, y: size.height - symbol.size.height))
            text.draw(at: CGPoint(x: size.width - ts.width, y: 0))
        }
        return Image(uiImage: image.withRenderingMode(.alwaysOriginal))
    }


    /// The toggle once there's enough data; until then, a quiet note of what's
    /// still needed (only for riders with Zone 2 rides to learn from).
    @ViewBuilder
    private var normalisedControl: some View {
        let n = viewModel.normalised
        if n.isReady {
            Toggle(isOn: $normalisedOn) {
                Text("Zone 2 power")
                    .font(.labelMedium)
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.switch)
            .tint(.green)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
        } else if !n.status.isEmpty && !viewModel.chartActivities.isEmpty {
            Text("Zone 2 power: \(n.status.prefix(1).lowercased() + n.status.dropFirst())")
                .font(.tiny)
                .foregroundColor(.secondary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
        }
    }

    private var normalisedChart: some View {
        let n = viewModel.normalised
        let pts = n.points
        let ws = pts.map(\.watts).sorted()
        let lo = (ws.isEmpty ? 100 : ws[max(0, ws.count / 20)]) - 10
        let hi = (ws.isEmpty ? 200 : ws[min(ws.count - 1, ws.count * 19 / 20)]) + 10
        let dateRange = calculateDateRange(dates: pts.map(\.date))
        let now = pts.last(where: { $0.trend != nil })?.trend

        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Zone 2 power (at \(n.targetHR) bpm)")
                    .font(.labelMedium.weight(.semibold))
                Spacer()
                if let now {
                    Text("Now \(Int(now.rounded())) W")
                        .font(.labelMedium.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            Chart {
                // Solid: from the ride's full data. Hollow: estimated from its
                // averages until the full data downloads.
                ForEach(pts.filter { !$0.isEstimate }, id: \.id) { p in
                    PointMark(x: .value("Date", p.date), y: .value("W", min(max(p.watts, lo), hi)))
                        .foregroundStyle(Color.green.opacity(0.4))
                        .symbolSize(22)
                }
                ForEach(pts.filter(\.isEstimate), id: \.id) { p in
                    PointMark(x: .value("Date", p.date), y: .value("W", min(max(p.watts, lo), hi)))
                        .symbol {
                            Circle().strokeBorder(Color.green.opacity(0.5), lineWidth: 1).frame(width: 6, height: 6)
                        }
                }
                ForEach(pts.filter { $0.trend != nil }, id: \.id) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Trend", p.trend ?? 0), series: .value("S", "trend"))
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: lo...hi)
            .chartXScale(domain: dateRange)
            .chartXAxis {
                AxisMarks(values: axisDates(for: dateRange)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: dateAxis(for: dateRange).format, anchor: .top)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel { if let w = value.as(Double.self) { Text("\(Int(w))").font(.tiny) } }
                }
            }
            .frame(height: 220)
            .padding(.horizontal)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newZoom = baseZoomLevel * value.magnification
                        withAnimation(.interactiveSpring) { zoomLevel = max(1.0, min(newZoom, 15.0)) }
                    }
                    .onEnded { _ in baseZoomLevel = zoomLevel }
            )

            if let fit = n.fit {
                Text("The power you hold at \(n.targetHR) bpm, your Zone 2 heart rate: higher is fitter. Each dot is one ride, adjusted to \(n.targetHR) bpm, 85 rpm and 30 minutes in; hollow dots are estimated from the ride's averages until its full data downloads. The line is the 61-day median. Your heart rate rises \(String(format: "%.2f", fit.beta)) bpm per watt.")
                    .font(.tiny)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
    }

    private var rawTrendChart: some View {
        let chartData = filterOutliers(viewModel.chartActivities.filter {
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
                            AxisMarks(values: axisDates(for: dateRange)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: dateAxis(for: dateRange).format, anchor: .top)
                            }
                        }

                        // HR lines (red) with Zone 2 band
                        Chart {
                            // Zone 2 band, clamped to the visible HR range. Unclamped,
                            // a zone reaching past the chart's top or bottom drew the
                            // band outside the plot, over the date labels and the
                            // zoom buttons.
                            let bandLow = max(Double(zone2Min), minHR)
                            let bandHigh = min(Double(zone2Max), maxHR)
                            if bandLow < bandHigh {
                                RectangleMark(
                                    yStart: .value("Zone Min", bandLow),
                                    yEnd: .value("Zone Max", bandHigh)
                                )
                                .foregroundStyle(.green.opacity(0.2))
                            }

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
                        // Same date axis as the power chart, drawn invisibly, so
                        // both plots are the same height and the HR layer (and
                        // its Zone 2 band) stops above the date labels.
                        .chartXAxis {
                            AxisMarks(values: axisDates(for: dateRange)) { _ in
                                AxisValueLabel(format: dateAxis(for: dateRange).format, anchor: .top)
                                    .foregroundStyle(.clear)
                            }
                        }
                        .chartPlotStyle { $0.clipped() }
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
                        .foregroundColor(.strava)
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

                Text("Lines break after 2+ week gaps")
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
    /// Download state of the ride's full second-by-second data, Netflix-style:
    /// a filled green tick when it's on the phone, a spinner while it's being
    /// fetched, a faint outline arrow while it's still to come. Plain values
    /// (not read through the view model) so the row redraws when they change.
    var hasFullData = false
    var isDownloading = false

    // Column widths scale with Dynamic Type, like the text in them. They were
    // fixed point widths sized for the default text size, so with a larger
    // text setting (seen on an iPad mini) the numbers outgrew their boxes —
    // durations truncated and heart rates wrapped onto two lines. At the
    // default size these resolve to exactly the old widths.
    @ScaledMetric(relativeTo: .body) private var durationWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .body) private var statWidth: CGFloat = 40

    var body: some View {
        HStack(spacing: 8) {
            // Date and time. `minWidth` rather than a fixed 105pt: the fixed
            // width was sized for a phone, so on a wider layout the date wrapped
            // inside its little box while the row had spare space beside it.
            Text(viewModel.formatDateWithTime(activity.startDate))
                .font(.labelMedium)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 105, alignment: .leading)

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
                .frame(width: durationWidth, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.tiny)
                        .foregroundColor(.blue)
                    Text(activity.averageWatts.map { "\(Int($0))" } ?? "-")
                        .font(.labelMedium)
                        .lineLimit(1)
                }
                .frame(width: statWidth, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.tiny)
                        .foregroundColor(.red)
                    Text(activity.averageHeartrate.map { "\(Int($0))" } ?? "-")
                        .font(.labelMedium)
                        .lineLimit(1)
                }
                .frame(width: statWidth, alignment: .leading)
            }

            Spacer()

            // Download state (see `hasFullData`). Same width in every state so
            // the columns stay aligned.
            Group {
                if isDownloading {
                    ProgressView().controlSize(.mini)
                } else if hasFullData {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.35))
                }
            }
            .frame(width: 14)
            .accessibilityLabel(isDownloading ? "Downloading full ride data" : hasFullData ? "Full ride data downloaded" : "Full ride data not downloaded yet")
        }
        .padding(.vertical, 1)
    }
}

struct LocalWorkoutRow: View {
    let local: LocalWorkout
    let viewModel: HistoryViewModel

    // Column widths scale with Dynamic Type, like the text in them. They were
    // fixed point widths sized for the default text size, so with a larger
    // text setting (seen on an iPad mini) the numbers outgrew their boxes —
    // durations truncated and heart rates wrapped onto two lines. At the
    // default size these resolve to exactly the old widths.
    @ScaledMetric(relativeTo: .body) private var durationWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .body) private var statWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var dateWidth: CGFloat = 130

    // "Not uploaded" only means something to a rider who uses Strava. For
    // everyone else a finished ride is just a ride.
    private var statusLabel: String? {
        switch local.status {
        case .inProgress: return "Interrupted"
        case .pendingUpload: return viewModel.isStravaConnected ? "Not uploaded" : nil
        }
    }

    private var statusIcon: String {
        switch local.status {
        case .inProgress: return "arrow.counterclockwise.circle"
        case .pendingUpload: return viewModel.isStravaConnected ? "icloud.and.arrow.up" : "figure.indoor.cycle"
        }
    }

    private var statusColor: Color {
        switch local.status {
        case .inProgress: return .orange
        case .pendingUpload: return viewModel.isStravaConnected ? .strava : .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.labelMedium)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.formatDateWithTime(local.workout.startDate))
                    .font(.labelMedium)
                    .lineLimit(1)
                if let statusLabel {
                    Text(statusLabel)
                        .font(.tiny)
                        .foregroundColor(statusColor)
                }
            }
            .frame(width: dateWidth, alignment: .leading)

            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.tiny)
                        .foregroundColor(.secondary)
                    Text(viewModel.formatDuration(Int(local.elapsedTime)))
                        .font(.labelMedium)
                        .lineLimit(1)
                }
                .frame(width: durationWidth, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.tiny)
                        .foregroundColor(.blue)
                    Text(local.workout.averagePower.map { "\($0)" } ?? "-")
                        .font(.labelMedium)
                        .lineLimit(1)
                }
                .frame(width: statWidth, alignment: .leading)

                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.tiny)
                        .foregroundColor(.red)
                    Text(local.workout.averageHeartRate.map { "\($0)" } ?? "-")
                        .font(.labelMedium)
                        .lineLimit(1)
                }
                .frame(width: statWidth, alignment: .leading)
            }

            Spacer()
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel(stravaService: StravaService()))
}

private extension UIFont {
    /// The rounded design of this font (falls back to the plain one).
    var rounded: UIFont {
        guard let d = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: d, size: pointSize)
    }
}
