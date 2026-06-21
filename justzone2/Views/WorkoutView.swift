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
        .overlay(alignment: .top) {
            if viewModel.isRevivingWatchHR {
                watchRevivingBanner
            }
        }
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
        // The Watch-error alert, navigation push to Summary, and the workout's
        // .onChange(of: state) MUST live on the outer Group, not on portraitBody.
        // Otherwise, if the workout completes (or fails) while the device is in
        // landscape, portraitBody isn't in the view hierarchy and none of these
        // modifiers fire — the user gets stuck on a frozen workout screen.
        .alert("Apple Watch", isPresented: .init(
            get: { viewModel.hrSourceError != nil },
            set: { if !$0 { viewModel.hrSourceError = nil } }
        )) {
            if viewModel.useWatchHR && (!viewModel.isWatchConnected || viewModel.isRevivingWatchHR) {
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
                        stravaService: stravaService,
                        zoneTargetingEnabled: viewModel.zoneTargetingEnabled,
                        warmUpEnabled: viewModel.warmUpEnabled,
                        hrSourceName: viewModel.hrSource.displayName,
                        zone2Min: viewModel.zone2MinValue,
                        zone2Max: viewModel.zone2MaxValue
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

            // Hero — the "am I in Zone 2?" answer at a glance (or warm-up countdown).
            Group {
                if viewModel.isWarmingUp {
                    warmUpHero
                } else {
                    zoneHero
                }
            }
            .padding(.top, 12)

            // Power + time as glass stat tiles.
            HStack(spacing: 12) {
                powerTile
                timeTile
            }
            .padding(.horizontal)
            .padding(.top, 14)

            // Live chart fills the remaining space.
            if !viewModel.chartData.isEmpty {
                WorkoutChartView(
                    chartData: viewModel.chartData,
                    targetPower: viewModel.adjustedPower
                )
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
                .padding(.top, 10)
            } else {
                Spacer()
                Text("Waiting for data…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
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
        .background(zoneTintedBackground)
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
            // Show the two NOT-currently-selected sources as switch options,
            // plus a Retry for Watch if it's selected but not delivering HR.
            if viewModel.hrSource != .appleWatch {
                Button("Switch to Apple Watch") {
                    viewModel.switchToWatchHR()
                }
            }
            if viewModel.hrSource != .airPods {
                Button("Switch to AirPods Pro") {
                    viewModel.switchToAirPods()
                }
            }
            if viewModel.hrSource != .bleStrap {
                Button("Switch to HR Strap") {
                    viewModel.switchToBLEHR()
                }
            }
            if viewModel.hrSource == .appleWatch && !viewModel.isWatchConnected {
                Button("Retry Watch Connection") {
                    viewModel.retryWatchConnection()
                }
            }
            if viewModel.hrSource == .bleStrap {
                Button("Change HR Strap") {
                    viewModel.startHRStrapSelection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(hrPickerMessage)
        }
        .sheet(isPresented: $viewModel.showHRStrapPicker) {
            viewModel.bluetoothManager.stopScanning()
        } content: {
            HRStrapPickerSheet(viewModel: viewModel)
        }
    }

    // MARK: - Zone hero + stat tiles (redesigned workout display)

    private var zoneMin: Int { viewModel.zone2MinValue }
    private var zoneMax: Int { viewModel.zone2MaxValue }
    private var hrRangeLo: Int { max(zoneMin - 20, 40) }
    private var hrRangeHi: Int { zoneMax + 30 }

    private func zoneFrac(_ value: Int) -> CGFloat {
        let lo = hrRangeLo, hi = hrRangeHi
        guard hi > lo else { return 0 }
        return CGFloat(min(max(Double(value - lo) / Double(hi - lo), 0), 1))
    }

    /// Green in Zone 2, amber above, blue below, grey before any HR.
    private var zoneColor: Color {
        let hr = viewModel.currentHeartRate
        if hr <= 0 { return .gray }
        if hr < zoneMin { return Color(red: 0.35, green: 0.70, blue: 1.0) }
        if hr > zoneMax { return Color(red: 1.0, green: 0.60, blue: 0.10) }
        return Color(red: 0.20, green: 0.85, blue: 0.45)
    }

    private var zoneStatusLabel: String {
        let hr = viewModel.currentHeartRate
        if hr <= 0 { return "WAITING FOR HR" }
        if hr < zoneMin { return "BELOW ZONE" }
        if hr > zoneMax { return "ABOVE ZONE" }
        return "IN ZONE 2"
    }

    /// Subtle top glow in the current zone colour — peripheral "are you in zone?"
    /// feedback. Orange during warm-up.
    private var zoneTintedBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)
            RadialGradient(
                colors: [(viewModel.isWarmingUp ? Color.orange : zoneColor).opacity(0.18), .clear],
                center: .top, startRadius: 0, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    private var zoneHero: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(zoneColor)
                    .symbolEffect(.pulse, options: .repeating)
                Text(viewModel.currentHeartRate > 0 ? "\(viewModel.currentHeartRate)" : "--")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundStyle(zoneColor)
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(zoneStatusLabel)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(zoneColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(zoneColor.opacity(0.16)))

            zoneBar
                .frame(height: 16)
                .padding(.horizontal, 34)
        }
    }

    private var zoneBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(Color.green.opacity(0.55))
                    .frame(width: w * (zoneFrac(zoneMax) - zoneFrac(zoneMin)))
                    .offset(x: w * zoneFrac(zoneMin))
                if viewModel.currentHeartRate > 0 {
                    Circle().fill(zoneColor)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                        .shadow(color: zoneColor.opacity(0.7), radius: 6)
                        .offset(x: w * zoneFrac(viewModel.currentHeartRate) - 8)
                }
            }
        }
    }

    private var warmUpHero: some View {
        VStack(spacing: 8) {
            Text("WARM UP")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundStyle(.orange)
            Text(viewModel.formatTime(viewModel.warmUpRemaining))
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.orange)
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").font(.subheadline).foregroundStyle(.red)
                Text(viewModel.currentHeartRate > 0 ? "\(viewModel.currentHeartRate) BPM" : "-- BPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var powerTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.yellow)
                Text("POWER").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary)
                Spacer()
                Button { viewModel.decrementPower() } label: {
                    Image(systemName: "minus.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.state != .running)
                Button { viewModel.incrementPower() } label: {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.state != .running)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.currentPower > 0 ? "\(viewModel.currentPower)" : "--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("W").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
            }
            Text(powerTargetSub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var powerTargetSub: String {
        if viewModel.zoneTargetingEnabled && viewModel.adjustedPower != viewModel.workout.targetPower {
            return "target \(viewModel.adjustedPower) W (set \(viewModel.workout.targetPower))"
        }
        return "target \(viewModel.adjustedPower) W"
    }

    private var timeTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "timer").font(.system(size: 12, weight: .bold)).foregroundStyle(.green)
                Text(viewModel.isWarmingUp ? "REMAINING" : "TIME LEFT")
                    .font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary)
                Spacer()
                if viewModel.state == .paused {
                    Text("PAUSED").font(.caption2.weight(.bold)).foregroundStyle(.orange)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.formatTime(viewModel.isWarmingUp ? viewModel.remainingTime : viewModel.timeRemainingInChunk))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }
            Text(timeSub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var timeSub: String {
        if viewModel.isWarmingUp { return "warming up" }
        return "Chunk \(viewModel.currentChunk) of \(viewModel.totalChunks) · \(viewModel.formatTime(viewModel.remainingTime)) total"
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

    /// Status text shown under the HR-source picker.
    private var hrPickerMessage: String {
        switch viewModel.hrSource {
        case .appleWatch:
            return viewModel.isHRSourceConnected
                ? "Currently using Apple Watch"
                : "Apple Watch not connected — tap Retry or switch source"
        case .airPods:
            return viewModel.isHRSourceConnected
                ? "Currently using AirPods Pro"
                : "Waiting for AirPods Pro — make sure they're worn"
        case .bleStrap:
            return viewModel.heartRateService.isConnected
                ? "Currently using HR Strap"
                : "No HR strap connected"
        }
    }

    /// "Connecting to {source}…" banner. Shown for any non-strap HR source
    /// while we're waiting for the first sample. Disappears as soon as the
    /// source publishes HR. Empty view otherwise so layout doesn't shift.
    @ViewBuilder
    private var connectingBanner: some View {
        if viewModel.hrSource != .bleStrap
            && !viewModel.isHRSourceConnected
            && (viewModel.state == .running || viewModel.state == .paused) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Connecting to \(viewModel.hrSource.displayName)…")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
        }
    }

    /// Subtle top banner shown while the watchdog is silently re-waking a
    /// stalled Watch HR stream mid-workout.
    private var watchRevivingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Reconnecting Apple Watch…")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
        .padding(.top, 8)
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
        steadyStateData.compactMap { point in
            guard let power = point.power else { return nil }
            return (time: point.time / 60, value: power)
        }
    }

    private var heartRateData: [(time: Double, value: Int)] {
        steadyStateData.compactMap { point in
            guard let hr = point.heartRate else { return nil }
            return (time: point.time / 60, value: hr)
        }
    }

    /// Skip the first 2 minutes of warm-up ramp from both the drawn series and
    /// the axis bounds — otherwise the low ramp-up values squash steady-state
    /// Zone 2 detail into a thin band, and drawing the warm-up while scaling to
    /// steady state clips it to the axis floor (a misleading vertical cliff).
    /// Once trimmed, the X-axis starts at the window so warm-up scrolls off
    /// cleanly. Falls back to all data while the workout is too young to have a
    /// meaningful steady-state.
    private static let warmupSkipSeconds: Double = 120

    private var steadyStateData: [ChartDataPoint] {
        let trimmed = chartData.filter { $0.time >= Self.warmupSkipSeconds }
        return trimmed.count >= 5 ? trimmed : chartData
    }

    private var powerRange: ClosedRange<Int> {
        let powers = steadyStateData.compactMap { $0.power }
        let minP = max(0, (powers.min() ?? 100) - 20)
        let maxP = max(powers.max() ?? 200, targetPower) + 20
        return minP...maxP
    }

    private var hrRange: ClosedRange<Int> {
        let hrs = steadyStateData.compactMap { $0.heartRate }
        let minHR = max(0, (hrs.min() ?? 60) - 10)
        let maxHR = (hrs.max() ?? 180) + 10
        return minHR...maxHR
    }

    private var minTime: Double {
        (steadyStateData.map { $0.time }.min() ?? 0) / 60
    }

    private var maxTime: Double {
        (steadyStateData.map { $0.time }.max() ?? 60) / 60
    }

    /// X-axis domain shared by both overlaid charts. Anchored at the window
    /// start so warm-up scrolls off once trimmed; always at least 1 min wide.
    private var timeDomain: ClosedRange<Double> {
        minTime...max(minTime + 1, maxTime)
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
                    .chartXScale(domain: timeDomain)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(position: .bottom)
                    }

                    // Heart rate chart (right axis)
                    Chart {
                        // Zone 2 HR band
                        RectangleMark(
                            xStart: .value("Start", timeDomain.lowerBound),
                            xEnd: .value("End", timeDomain.upperBound),
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
                    .chartXScale(domain: timeDomain)
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