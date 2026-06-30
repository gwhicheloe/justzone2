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
                        zone2Max: viewModel.zone2MaxValue,
                        isDemo: viewModel.isDemo
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
                HStack(spacing: 6) {
                    Text(stateTitle)
                        .font(.custom("ArialRoundedMTBold", size: 28))
                        .foregroundColor(viewModel.isWarmingUp ? .orange : .green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    DemoTitleTag()
                }
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
    // Equal margin either side of the Zone 2 band so the green band sits centred
    // in the bar (you can see equally how far above/below zone you are).
    private var hrRangeLo: Int { max(zoneMin - 25, 40) }
    private var hrRangeHi: Int { zoneMax + 25 }

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
            HStack(spacing: 4) {
                // No bolt glyph here: the ±5W steppers already give the power
                // header its visual weight, and dropping it frees the width the
                // big steppers need so "POWER" never wraps on a narrow phone.
                Text("POWER").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.secondary).lineLimit(1).fixedSize()
                Spacer(minLength: 2)
                powerStepper("minus.circle.fill", action: { viewModel.decrementPower() })
                powerStepper("plus.circle.fill", action: { viewModel.incrementPower() })
            }
            .frame(height: 30)          // matches the time tile's header height so
                                        // both grey boxes end up exactly the same size
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.currentPower > 0 ? "\(viewModel.currentPower)" : "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("W").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text(powerTargetSub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func powerStepper(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(viewModel.state == .running ? Color.blue : Color.secondary.opacity(0.5))
                .frame(width: 40, height: 30)          // generous touch target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state != .running)
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
            .frame(height: 30)          // matches the power tile's header height
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(viewModel.formatTime(viewModel.isWarmingUp ? viewModel.remainingTime : viewModel.timeRemainingInChunk))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

    /// Wall-clock time the most recent sample arrived — lets the x-domain advance
    /// smoothly between 1 Hz samples so the live chart scrolls continuously.
    @State private var lastDataArrival = Date()

    // Palette tuned to the redesigned workout screen (refined, not raw RGB).
    private static let powerColor = Color(red: 0.27, green: 0.60, blue: 1.0)
    private static let hrColor    = Color(red: 1.0, green: 0.34, blue: 0.34)
    private static let zoneColor  = Color(red: 0.20, green: 0.85, blue: 0.45)

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

    /// Centred rolling average — turns beat-to-beat / pedal-stroke jitter into a
    /// clean trend line. Small window so it tracks changes without lag; the metric
    /// tiles already show the instantaneous numbers.
    private func smoothed(_ pts: [(time: Double, value: Int)], window: Int = 5) -> [(time: Double, value: Int)] {
        guard pts.count > window else { return pts }
        let half = window / 2
        return pts.indices.map { i in
            let lo = max(0, i - half), hi = min(pts.count - 1, i + half)
            var sum = 0
            for j in lo...hi { sum += pts[j].value }
            return (time: pts[i].time, value: Int((Double(sum) / Double(hi - lo + 1)).rounded()))
        }
    }

    private var smoothedPowerData: [(time: Double, value: Int)] { smoothed(powerData) }
    // HR gets only a light 3-sample touch — straps already output a clean signal,
    // so we keep the trace honest rather than flattening real changes.
    private var smoothedHeartRateData: [(time: Double, value: Int)] { smoothed(heartRateData, window: 3) }

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

    /// Round a data span out to tidy bounds whose midpoint is also a round
    /// number, so the three side-scale labels are always clean multiples of `step`.
    private func niceBounds(min lo: Int, max hi: Int, step: Int) -> ClosedRange<Int> {
        var low = (Int(floor(Double(lo) / Double(step)))) * step
        var high = (Int(ceil(Double(hi) / Double(step)))) * step
        if high <= low { high = low + step }
        // Even number of steps ⇒ the midpoint lands exactly on a step.
        if ((high - low) / step) % 2 != 0 { high += step }
        return max(0, low)...high
    }

    private var powerRange: ClosedRange<Int> {
        let powers = steadyStateData.compactMap { $0.power }
        let minP = (powers.min() ?? 100) - 15
        let maxP = max(powers.max() ?? 200, targetPower) + 15
        return niceBounds(min: minP, max: maxP, step: 20)
    }

    private var hrRange: ClosedRange<Int> {
        let hrs = steadyStateData.compactMap { $0.heartRate }
        // Always include the Zone 2 band so it can't be clipped early on when
        // there's barely any HR data yet.
        let minHR = min(hrs.min() ?? 999, zone2Min) - 8
        let maxHR = max(hrs.max() ?? 0, zone2Max) + 8
        return niceBounds(min: minHR, max: maxHR, step: 10)
    }

    private var minTime: Double {
        (steadyStateData.map { $0.time }.min() ?? 0) / 60
    }

    private var maxTime: Double {
        (steadyStateData.map { $0.time }.max() ?? 60) / 60
    }

    /// X-axis domain shared by both overlaid charts, with its right edge advancing
    /// smoothly from the last sample toward "now" (capped at one sample interval)
    /// so the trace scrolls continuously instead of jumping each second. Both
    /// charts and the leading dots project through this same domain, so the dots
    /// stay exactly on the line tips.
    private func scrollDomain(now: Date) -> ClosedRange<Double> {
        let advance = min(max(now.timeIntervalSince(lastDataArrival), 0), Constants.sampleInterval) / 60.0
        let lo = minTime
        let hi = max(lo + 1, maxTime + advance)
        return lo...hi
    }

    /// Whole-minute X tick positions, with the spacing widening as the workout
    /// grows so labels stay round (1, 2, 5, 10 min) and never crowd.
    private var xTicks: [Double] {
        let span = max(maxTime - minTime, 0.1)
        let step: Double = span < 3 ? 1 : (span < 8 ? 2 : (span < 20 ? 5 : 10))
        let first = (minTime / step).rounded(.up) * step
        return Array(stride(from: first, through: maxTime, by: step))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                axisScale(top: powerRange.upperBound, bottom: powerRange.lowerBound, tint: Self.powerColor)

                // Re-projects every frame so the domain (and everything on it)
                // scrolls smoothly rather than stepping once per sample.
                TimelineView(.animation) { context in
                    let domain = scrollDomain(now: context.date)
                    ZStack {
                        powerChart(domain: domain)
                        heartRateChart(domain: domain)
                    }
                }
                .frame(height: 150)

                axisScale(top: hrRange.upperBound, bottom: hrRange.lowerBound, tint: Self.hrColor)
            }

            legend
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        .onChange(of: chartData.count) { _, _ in lastDataArrival = Date() }
    }

    /// Power: a smoothed gradient area under a rounded line, with the target as a
    /// faint dashed rule (blue — it belongs to power, not the green HR zone) and
    /// the live "now" dot drawn as an overlay (see `leadingDot`). The area is only
    /// drawn once there are ≥2 points — a single point collapses the fill into a
    /// thin vertical "dagger" down to the baseline.
    private func powerChart(domain: ClosedRange<Double>) -> some View {
        Chart {
            RuleMark(y: .value("Target", targetPower))
                .foregroundStyle(Self.powerColor.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            if smoothedPowerData.count >= 2 {
                ForEach(Array(smoothedPowerData.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("Time", point.time), y: .value("Power", point.value))
                        .foregroundStyle(.linearGradient(
                            colors: [Self.powerColor.opacity(0.32), Self.powerColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
            }
            ForEach(Array(smoothedPowerData.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Time", point.time), y: .value("Power", point.value))
                    .foregroundStyle(Self.powerColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: powerRange)
        .chartXScale(domain: domain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(position: .bottom, values: xTicks) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel {
                    if let m = value.as(Double.self) { Text("\(Int(m))") }
                }
                .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .chartOverlay { proxy in
            leadingDot(proxy: proxy, point: smoothedPowerData.last, color: Self.powerColor)
        }
    }

    /// Heart rate: a clean smoothed line riding over the soft Zone 2 band. The
    /// (clear) X axis here keeps this chart's plot inset identical to the power
    /// chart's so the two overlaid series stay pixel-aligned.
    private func heartRateChart(domain: ClosedRange<Double>) -> some View {
        Chart {
            RectangleMark(
                xStart: .value("Start", domain.lowerBound),
                xEnd: .value("End", domain.upperBound),
                yStart: .value("Zone Min", zone2Min),
                yEnd: .value("Zone Max", zone2Max)
            )
            .foregroundStyle(.linearGradient(
                colors: [Self.zoneColor.opacity(0.28), Self.zoneColor.opacity(0.12)],
                startPoint: .top, endPoint: .bottom))

            ForEach(Array(smoothedHeartRateData.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Time", point.time), y: .value("HR", point.value))
                    .foregroundStyle(Self.hrColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: hrRange)
        .chartXScale(domain: domain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(position: .bottom, values: xTicks) { _ in
                AxisValueLabel().font(.system(size: 9)).foregroundStyle(.clear)
            }
        }
        .chartOverlay { proxy in
            leadingDot(proxy: proxy, point: smoothedHeartRateData.last, color: Self.hrColor)
        }
    }

    /// The live "now" dot — a soft halo + solid core anchored to the leading data
    /// point through the chart's own scales. Because it projects through the same
    /// per-frame `scrollDomain` as the line, it rides exactly on the line's tip as
    /// the chart scrolls — no separate animation that could drift.
    @ViewBuilder
    private func leadingDot(proxy: ChartProxy, point: (time: Double, value: Int)?, color: Color) -> some View {
        if let point, let anchor = proxy.plotFrame {
            GeometryReader { geo in
                let frame = geo[anchor]
                let x = frame.minX + (proxy.position(forX: point.time) ?? 0)
                let y = frame.minY + (proxy.position(forY: point.value) ?? 0)
                ZStack {
                    Circle().fill(color.opacity(0.22)).frame(width: 18, height: 18)
                    Circle().fill(color).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                }
                .position(x: x, y: y)
            }
        }
    }

    /// Compact 3-value side scale (top / mid / bottom), tinted to its series.
    private func axisScale(top: Int, bottom: Int, tint: Color) -> some View {
        VStack(alignment: .leading) {
            Text("\(top)")
            Spacer()
            Text("\((top + bottom) / 2)")
            Spacer()
            Text("\(bottom)")
        }
        .font(.system(size: 9, weight: .medium).monospacedDigit())
        .foregroundStyle(tint.opacity(0.7))
        .frame(width: 28)
        .padding(.bottom, 12)   // align the bottom value with the plot floor (above the X labels)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Self.powerColor, label: "Power")
            legendItem(color: Self.hrColor, label: "HR")
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(Self.zoneColor.opacity(0.5)).frame(width: 14, height: 8)
                Text("Zone 2")
            }
            Spacer()
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 14, height: 3)
            Text(label)
        }
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
