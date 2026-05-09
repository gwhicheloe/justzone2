import SwiftUI
import Charts

struct WorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    let stravaService: StravaService
    @Binding var isPresented: Bool
    @State private var showSummary = false
    @State private var summaryViewModel: SummaryViewModel?
    @State private var showHRSourcePicker = false
    @State private var shareETAText: String?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        Group {
            if isLandscape {
                landscapeBody
            } else {
                portraitBody
            }
        }
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        // The Watch-error alert, navigation push to Summary, and the workout's
        // .onChange(of: state) MUST live on the outer Group, not on portraitBody.
        // Otherwise, if the workout completes (or fails) while the device is in
        // landscape, portraitBody isn't in the view hierarchy and none of these
        // modifiers fire — the user gets stuck on a frozen workout screen.
        .alert("Apple Watch", isPresented: .init(
            get: { viewModel.hrSourceError != nil },
            set: { if !$0 { viewModel.hrSourceError = nil } }
        )) {
            if viewModel.useWatchHR && !viewModel.isWatchConnected {
                Button("Retry") {
                    viewModel.hrSourceError = nil
                    viewModel.retryWatchConnection()
                }
                Button("Use HR Strap") {
                    viewModel.hrSourceError = nil
                    viewModel.switchToBLEHR()
                }
                Button("Cancel", role: .cancel) { viewModel.hrSourceError = nil }
            } else {
                Button("OK") { viewModel.hrSourceError = nil }
            }
        } message: {
            if let error = viewModel.hrSourceError {
                Text(error)
            }
        }
        .navigationDestination(isPresented: $showSummary) {
            if let summaryVM = summaryViewModel {
                SummaryView(
                    viewModel: summaryVM,
                    onDismiss: {
                        isPresented = false
                    }
                )
            }
        }
        .onAppear {
            AppDelegate.orientationLock = .allButUpsideDown
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .forEach { $0.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }

            if viewModel.state == .idle {
                // Small delay to ensure view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.startWorkout()
                }
            }
        }
        .onDisappear {
            AppDelegate.orientationLock = .portrait
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .forEach { $0.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .completed {
                // Force portrait so SummaryView (designed for portrait) renders
                // correctly even if the user was in landscape when auto-complete
                // fired.
                AppDelegate.orientationLock = .portrait
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .forEach { $0.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }

                if summaryViewModel == nil {
                    summaryViewModel = SummaryViewModel(
                        workout: viewModel.workout,
                        stravaService: stravaService
                    )
                }
                showSummary = true
            }
        }
    }

    /// Landscape: chart fills the screen with only a thin progress bar and a
    /// tiny chunk-status line at the top. Rotate back to portrait for controls.
    private var landscapeBody: some View {
        VStack(spacing: 4) {
            // Progress bar with chunk dividers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.gray.opacity(0.3))
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * viewModel.progress)
                    ForEach(1..<viewModel.totalChunks, id: \.self) { chunk in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2)
                            .offset(x: geometry.size.width * (Double(chunk) / Double(viewModel.totalChunks)) - 1)
                    }
                }
            }
            .frame(height: 4)

            connectingBanner

            // Tiny status row
            HStack {
                Text("Chunk \(viewModel.currentChunk) of \(viewModel.totalChunks)")
                    .fontWeight(.semibold)
                Text("·")
                    .foregroundColor(.secondary)
                Text("\(viewModel.formatTime(viewModel.timeRemainingInChunk)) left")
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.state == .paused {
                    Text("PAUSED")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.top, 2)

            // Chart fills remaining space
            if !viewModel.chartData.isEmpty {
                WorkoutChartView(
                    chartData: viewModel.chartData,
                    targetPower: viewModel.adjustedPower
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            } else {
                Spacer()
                Text("Waiting for data…")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var portraitBody: some View {
        VStack(spacing: 0) {
            // Progress Bar with Chunk Markers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))

                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * viewModel.progress)

                    // Chunk dividers
                    ForEach(1..<viewModel.totalChunks, id: \.self) { chunk in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2)
                            .offset(x: geometry.size.width * (Double(chunk) / Double(viewModel.totalChunks)) - 1)
                    }
                }
            }
            .frame(height: 8)

            connectingBanner

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

                        // Power metric with manual ±5W buttons
                        HStack(spacing: 8) {
                            Button(action: { viewModel.decrementPower() }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                            .disabled(viewModel.state != .running)

                            CompactMetricView(
                                icon: "bolt.fill",
                                iconColor: .blue,
                                value: viewModel.currentPower > 0 ? "\(viewModel.currentPower)" : "--",
                                unit: "W",
                                targetValue: viewModel.adjustedPower,
                                originalTarget: viewModel.zoneTargetingEnabled && viewModel.adjustedPower != viewModel.workout.targetPower
                                    ? viewModel.workout.targetPower : nil
                            )

                            Button(action: { viewModel.incrementPower() }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                            .disabled(viewModel.state != .running)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 12)

                    // Time display
                    VStack(spacing: 8) {
                        if viewModel.isWarmingUp {
                            // Warm-up countdown
                            Text(viewModel.formatTime(viewModel.warmUpRemaining))
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.orange)

                            HStack(spacing: 24) {
                                VStack(spacing: 2) {
                                    Text(viewModel.formatTime(viewModel.elapsedTime))
                                        .font(.title3)
                                        .monospacedDigit()
                                    Text("elapsed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                VStack(spacing: 2) {
                                    Text(viewModel.formatTime(viewModel.remainingTime))
                                        .font(.title3)
                                        .monospacedDigit()
                                    Text("remaining")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Normal chunk-based display
                            Text("Chunk \(viewModel.currentChunk) of \(viewModel.totalChunks)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(viewModel.formatTime(viewModel.timeRemainingInChunk))
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.green)

                            HStack(spacing: 24) {
                                VStack(spacing: 2) {
                                    Text(viewModel.formatTime(viewModel.elapsedTime))
                                        .font(.title3)
                                        .monospacedDigit()
                                    Text("elapsed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                VStack(spacing: 2) {
                                    Text(viewModel.formatTime(viewModel.remainingTime))
                                        .font(.title3)
                                        .monospacedDigit()
                                    Text("remaining")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Chart
                    if !viewModel.chartData.isEmpty {
                        WorkoutChartView(
                            chartData: viewModel.chartData,
                            targetPower: viewModel.adjustedPower
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }

                // Controls
                VStack(spacing: 16) {
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
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }

                    // Zone Targeting toggle
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.zoneTargetingEnabled ? "heart.text.square.fill" : "heart.text.square")
                            .foregroundColor(viewModel.zoneTargetingEnabled ? .green : .secondary)
                        Text("Zone Targeting")
                            .font(.subheadline)
                            .foregroundColor(viewModel.zoneTargetingEnabled ? .primary : .secondary)
                        Toggle("", isOn: $viewModel.zoneTargetingEnabled)
                            .labelsHidden()
                            .tint(.green)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(stateTitle)
                    .font(.custom("ArialRoundedMTBold", size: 28))
                    .foregroundColor(viewModel.isWarmingUp ? .orange : .green)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareETAText = buildETAMessage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.green)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHRSourcePicker = true
                } label: {
                    ZStack {
                        Image(systemName: "heart.circle.fill")
                            .font(.title2)
                            .foregroundColor(hrSourceIconColor)

                        if viewModel.isSwitchingHRSource {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                    }
                }
                .disabled(viewModel.isSwitchingHRSource)
            }
        }
        .sheet(item: Binding(
            get: { shareETAText.map { ShareItem(text: $0) } },
            set: { shareETAText = $0?.text }
        )) { item in
            ShareSheet(items: [item.text])
        }
        .confirmationDialog("Heart Rate Source", isPresented: $showHRSourcePicker) {
            if viewModel.useWatchHR {
                Button("Switch to HR Strap") {
                    viewModel.switchToBLEHR()
                }
                if !viewModel.isWatchConnected {
                    Button("Retry Watch Connection") {
                        viewModel.retryWatchConnection()
                    }
                }
            } else {
                Button("Switch to Apple Watch") {
                    viewModel.switchToWatchHR()
                }
                Button("Change HR Strap") {
                    viewModel.startHRStrapSelection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if viewModel.useWatchHR {
                if viewModel.isWatchConnected {
                    Text("Currently using Apple Watch")
                } else {
                    Text("Apple Watch not connected — tap Retry or switch to HR strap")
                }
            } else {
                if viewModel.heartRateService.isConnected {
                    Text("Currently using HR Strap")
                } else {
                    Text("No HR strap connected")
                }
            }
        }
        .sheet(isPresented: $viewModel.showHRStrapPicker) {
            viewModel.bluetoothManager.stopScanning()
        } content: {
            HRStrapPickerSheet(viewModel: viewModel)
        }
    }

    private var hrSourceIconColor: Color {
        if viewModel.isSwitchingHRSource {
            return .gray
        }
        if viewModel.useWatchHR && !viewModel.isWatchConnected {
            return .orange
        }
        return .green
    }

    private var stateTitle: String {
        switch viewModel.state {
        case .idle:
            return "Starting..."
        case .running:
            return viewModel.isWarmingUp ? "Warm Up" : "Zone 2 Workout"
        case .paused:
            return "Paused"
        case .completed:
            return "Complete"
        }
    }

    /// "Connecting to Apple Watch…" banner. Shown when the user picked Watch
    /// HR but no sample has arrived yet. Disappears as soon as `hasWatchHR`
    /// flips true. Empty view otherwise so layout doesn't shift.
    @ViewBuilder
    private var connectingBanner: some View {
        if viewModel.useWatchHR
            && !viewModel.hasWatchHR
            && (viewModel.state == .running || viewModel.state == .paused) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Connecting to Apple Watch…")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
        }
    }

    /// Build the share-ETA message text. Recomputes on each tap so sharing
    /// mid-workout produces an accurate "done by" time.
    private func buildETAMessage() -> String {
        let remaining = max(viewModel.workout.targetDuration - viewModel.elapsedTime, 0)
        let endTime = Date().addingTimeInterval(remaining)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Doing a Zone 2 ride. Done by \(formatter.string(from: endTime)) 🚴"
    }
}

/// Identifiable wrapper so we can drive a sheet from an optional String.
private struct ShareItem: Identifiable {
    let text: String
    var id: String { text }
}


struct CompactMetricView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let unit: String
    var targetValue: Int? = nil
    var originalTarget: Int? = nil

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

            Group {
                if let target = targetValue {
                    if let original = originalTarget {
                        HStack(spacing: 4) {
                            Text("Target: \(target)W")
                                .font(.labelSmall)
                                .foregroundColor(.green)
                            Text("(\(original)W)")
                                .font(.labelSmall)
                                .foregroundColor(.secondary)
                        }
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    } else {
                        Text("Target: \(target)W")
                            .font(.labelSmall)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Color.clear
                }
            }
            .frame(height: 20)
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

struct HRStrapPickerSheet: View {
    @ObservedObject var viewModel: WorkoutViewModel

    private var hrMonitors: [DeviceInfo] {
        Array(viewModel.bluetoothManager.discoveredHRMonitors.prefix(5))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if hrMonitors.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning for HR monitors...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(hrMonitors) { device in
                        Button {
                            viewModel.selectAndConnectHRStrap(device)
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(viewModel.heartRateService.connectedDeviceId == device.id ? .green : .red)
                                Text(device.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.heartRateService.connectedDeviceId == device.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select HR Strap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showHRStrapPicker = false
                        viewModel.bluetoothManager.stopScanning()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var bluetooth = BluetoothManager()
    NavigationStack {
        WorkoutView(
            viewModel: WorkoutViewModel(
                workout: Workout(targetPower: 150, targetDuration: 30 * 60),
                bluetoothManager: bluetooth,
                kickrService: KickrService(bluetoothManager: bluetooth),
                heartRateService: HeartRateService(bluetoothManager: bluetooth),
                healthKitManager: HealthKitManager(),
                liveActivityManager: LiveActivityManager(),
                watchConnectivityService: WatchConnectivityService()
            ),
            stravaService: StravaService(),
            isPresented: .constant(true)
        )
    }
}
