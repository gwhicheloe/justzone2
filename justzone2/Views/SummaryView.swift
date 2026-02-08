import SwiftUI
import Photos
import Charts

struct SummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    var onDismiss: () -> Void
    @State private var chartSaved = false
    @State private var uploadState: UploadState = .ready

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                Text("Workout Complete!")
                    .font(.headlineLarge)

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Duration",
                        value: viewModel.formatDuration(viewModel.workout.actualDuration),
                        icon: "clock.fill"
                    )

                    StatCard(
                        title: "Avg Power",
                        value: viewModel.workout.averagePower.map { "\($0)W" } ?? "--",
                        icon: "bolt.fill"
                    )

                    StatCard(
                        title: "Avg HR",
                        value: viewModel.workout.averageHeartRate.map { "\($0)" } ?? "--",
                        icon: "heart.fill"
                    )

                    StatCard(
                        title: "Max HR",
                        value: viewModel.workout.maxHeartRate.map { "\($0)" } ?? "--",
                        icon: "heart.fill"
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Workout Chart
                if !viewModel.workout.samples.isEmpty {
                    SummaryChartView(workout: viewModel.workout)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }

                // Strava Section
                VStack(spacing: 16) {
                    Text("Strava")
                        .font(.headlineMedium)
                        .foregroundColor(.strava)

                    if !viewModel.isStravaConnected {
                        Button(action: {
                            Task {
                                await viewModel.connectToStrava()
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect with Strava")
                            }
                            .font(.headlineSmall)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.strava)
                            .cornerRadius(12)
                        }
                    } else {
                        // Upload button - changes appearance based on state
                        VStack(spacing: 12) {
                            UploadButton(state: uploadState) {
                                // Immediate local feedback
                                uploadState = .processing
                                viewModel.upload()
                            }

                            // Show Strava link after successful upload
                            if case .complete(let activityId) = uploadState {
                                Link(destination: URL(string: "https://www.strava.com/activities/\(activityId)")!) {
                                    HStack {
                                        Text("View on Strava")
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.bodyMedium)
                                    .foregroundColor(.strava)
                                }
                            }

                            if chartSaved {
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.blue)
                                    Text("Chart saved to Photos")
                                        .font(.labelMedium)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onDismiss()
                    }) {
                        Text("Done")
                            .font(.headlineSmall)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.discardWorkout()
                        onDismiss()
                    }) {
                        Text("Discard Workout")
                            .font(.bodyMedium)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Summary")
                    .font(.custom("ArialRoundedMTBold", size: 28))
                    .foregroundColor(.green)
            }
        }
        .onReceive(viewModel.$uploadState) { newState in
            uploadState = newState
            if case .complete = newState {
                saveChartToPhotos()
            }
        }
    }

    @MainActor
    private func saveChartToPhotos() {
        let exportView = ExportableChartView(workout: viewModel.workout)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0
        renderer.proposedSize = .init(width: 600, height: 450)

        guard let image = renderer.uiImage else { return }

        // Convert to JPEG (opaque, no alpha channel) to avoid memory warnings
        guard let jpegData = image.jpegData(compressionQuality: 0.9),
              let jpegImage = UIImage(data: jpegData) else { return }

        UIImageWriteToSavedPhotosAlbum(jpegImage, nil, nil, nil)
        chartSaved = true
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headlineMedium)

            Text(title)
                .font(.labelMedium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct UploadButton: View {
    let state: UploadState
    let action: () -> Void

    private var buttonColor: Color {
        switch state {
        case .ready: return .strava
        case .processing: return .gray
        case .complete: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                switch state {
                case .ready:
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Upload to Strava")
                case .processing:
                    ProgressView()
                        .tint(.white)
                    Text("Uploading...")
                case .complete:
                    Image(systemName: "checkmark.circle.fill")
                    Text("Uploaded to Strava")
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Failed - Tap to Retry")
                }
            }
            .font(.headlineSmall)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(buttonColor)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!state.canTap)
    }
}

// Chart for display in summary
struct SummaryChartView: View {
    let workout: Workout

    private var chartData: [ChartDataPoint] {
        workout.samples.enumerated().map { index, sample in
            ChartDataPoint(
                time: sample.timestamp,
                heartRate: sample.heartRate,
                power: sample.power
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Chart")
                .font(.headlineSmall)

            MiniChartView(chartData: chartData, targetPower: workout.targetPower)
                .frame(height: 150)
        }
    }
}

// Branded chart for export to photos - uses simple Path drawing for ImageRenderer compatibility
// Note: Uses explicit fonts for ImageRenderer compatibility with Arial Rounded
struct ExportableChartView: View {
    let workout: Workout

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.startDate)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            // Background
            Color.white

            // Large pale green "2" watermark
            Text("2")
                .font(.custom("ArialRoundedMTBold", size: 500))
                .foregroundColor(Color.green.opacity(0.15))
                .offset(x: 100, y: 50)

            // Content
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zone 2 Workout")
                            .font(.custom("ArialRoundedMTBold", size: 28))
                            .foregroundColor(.black)
                        Text(dateString)
                            .font(.custom("ArialRoundedMTBold", size: 15))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("JustZone2")
                        .font(.custom("ArialRoundedMTBold", size: 17))
                        .foregroundColor(.green)
                }
                .padding(.horizontal)

                // Stats row
                HStack(spacing: 20) {
                    ExportStatView(
                        title: "Duration",
                        value: formatDuration(workout.actualDuration)
                    )
                    ExportStatView(
                        title: "Avg Power",
                        value: workout.averagePower.map { "\($0)W" } ?? "--"
                    )
                    ExportStatView(
                        title: "Avg HR",
                        value: workout.averageHeartRate.map { "\($0) bpm" } ?? "--"
                    )
                    ExportStatView(
                        title: "Target",
                        value: "\(workout.targetPower)W"
                    )
                }
                .padding(.horizontal)

                // Simple chart using Path (compatible with ImageRenderer)
                SimpleExportChartView(workout: workout)
                    .frame(width: 540, height: 200)

                // Legend
                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 10, height: 10)
                        Text("Power (W)")
                            .font(.custom("ArialRoundedMTBold", size: 12))
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("Heart Rate (bpm)")
                            .font(.custom("ArialRoundedMTBold", size: 12))
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.green.opacity(0.5))
                            .frame(width: 20, height: 2)
                        Text("Target")
                            .font(.custom("ArialRoundedMTBold", size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 24)
        }
        .frame(width: 600, height: 450)
    }
}

// Simple chart using Path for ImageRenderer compatibility
struct SimpleChartView: View {
    let workout: Workout

    private var powerData: [(x: CGFloat, y: CGFloat)] {
        guard !workout.samples.isEmpty else { return [] }
        let maxTime = workout.samples.last?.timestamp ?? 1
        let powers = workout.samples.compactMap { $0.power }
        let minP = CGFloat(max(0, (powers.min() ?? 100) - 20))
        let maxP = CGFloat(max(powers.max() ?? 200, workout.targetPower) + 20)
        let range = maxP - minP

        return workout.samples.compactMap { sample -> (x: CGFloat, y: CGFloat)? in
            guard let power = sample.power else { return nil }
            let x = CGFloat(sample.timestamp / maxTime)
            let y = 1 - (CGFloat(power) - minP) / range
            return (x: x, y: y)
        }
    }

    private var hrData: [(x: CGFloat, y: CGFloat)] {
        guard !workout.samples.isEmpty else { return [] }
        let maxTime = workout.samples.last?.timestamp ?? 1
        let hrs = workout.samples.compactMap { $0.heartRate }
        let minHR = CGFloat(max(0, (hrs.min() ?? 60) - 10))
        let maxHR = CGFloat((hrs.max() ?? 180) + 10)
        let range = maxHR - minHR

        return workout.samples.compactMap { sample -> (x: CGFloat, y: CGFloat)? in
            guard let hr = sample.heartRate else { return nil }
            let x = CGFloat(sample.timestamp / maxTime)
            let y = 1 - (CGFloat(hr) - minHR) / range
            return (x: x, y: y)
        }
    }

    private var targetY: CGFloat {
        let powers = workout.samples.compactMap { $0.power }
        let minP = CGFloat(max(0, (powers.min() ?? 100) - 20))
        let maxP = CGFloat(max(powers.max() ?? 200, workout.targetPower) + 20)
        let range = maxP - minP
        return 1 - (CGFloat(workout.targetPower) - minP) / range
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))

                // Target line
                Path { path in
                    let y = targetY * geometry.size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

                // Power line
                Path { path in
                    guard let first = powerData.first else { return }
                    path.move(to: CGPoint(
                        x: first.x * geometry.size.width,
                        y: first.y * geometry.size.height
                    ))
                    for point in powerData.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        ))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                // HR line
                Path { path in
                    guard let first = hrData.first else { return }
                    path.move(to: CGPoint(
                        x: first.x * geometry.size.width,
                        y: first.y * geometry.size.height
                    ))
                    for point in hrData.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        ))
                    }
                }
                .stroke(Color.red, lineWidth: 2)
            }
        }
    }
}

// Fixed-size chart for ImageRenderer (no GeometryReader)
struct SimpleExportChartView: View {
    let workout: Workout
    let width: CGFloat = 540
    let height: CGFloat = 200

    private var powerData: [(x: CGFloat, y: CGFloat)] {
        guard !workout.samples.isEmpty else { return [] }
        let maxTime = workout.samples.last?.timestamp ?? 1
        let powers = workout.samples.compactMap { $0.power }
        guard !powers.isEmpty else { return [] }
        let minP = CGFloat(max(0, (powers.min() ?? 100) - 20))
        let maxP = CGFloat(max(powers.max() ?? 200, workout.targetPower) + 20)
        let range = max(maxP - minP, 1)

        return workout.samples.compactMap { sample -> (x: CGFloat, y: CGFloat)? in
            guard let power = sample.power else { return nil }
            let x = CGFloat(sample.timestamp / maxTime)
            let y = 1 - (CGFloat(power) - minP) / range
            return (x: x, y: y)
        }
    }

    private var hrData: [(x: CGFloat, y: CGFloat)] {
        guard !workout.samples.isEmpty else { return [] }
        let maxTime = workout.samples.last?.timestamp ?? 1
        let hrs = workout.samples.compactMap { $0.heartRate }
        guard !hrs.isEmpty else { return [] }
        let minHR = CGFloat(max(0, (hrs.min() ?? 60) - 10))
        let maxHR = CGFloat((hrs.max() ?? 180) + 10)
        let range = max(maxHR - minHR, 1)

        return workout.samples.compactMap { sample -> (x: CGFloat, y: CGFloat)? in
            guard let hr = sample.heartRate else { return nil }
            let x = CGFloat(sample.timestamp / maxTime)
            let y = 1 - (CGFloat(hr) - minHR) / range
            return (x: x, y: y)
        }
    }

    private var targetY: CGFloat {
        let powers = workout.samples.compactMap { $0.power }
        guard !powers.isEmpty else { return 0.5 }
        let minP = CGFloat(max(0, (powers.min() ?? 100) - 20))
        let maxP = CGFloat(max(powers.max() ?? 200, workout.targetPower) + 20)
        let range = max(maxP - minP, 1)
        return 1 - (CGFloat(workout.targetPower) - minP) / range
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))

            // Target line
            Path { path in
                let y = targetY * height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

            // Power line
            Path { path in
                guard let first = powerData.first else { return }
                path.move(to: CGPoint(x: first.x * width, y: first.y * height))
                for point in powerData.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * width, y: point.y * height))
                }
            }
            .stroke(Color.blue, lineWidth: 2)

            // HR line
            Path { path in
                guard let first = hrData.first else { return }
                path.move(to: CGPoint(x: first.x * width, y: first.y * height))
                for point in hrData.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * width, y: point.y * height))
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
    }
}

struct ExportStatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("ArialRoundedMTBold", size: 20))
                .foregroundColor(.black)
            Text(title)
                .font(.custom("ArialRoundedMTBold", size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// Simple chart view for both display and export
struct MiniChartView: View {
    let chartData: [ChartDataPoint]
    let targetPower: Int

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
        HStack(spacing: 0) {
            // Left Y-axis (Power)
            VStack {
                Text("\(powerRange.upperBound)")
                Spacer()
                Text("\(powerRange.lowerBound)")
            }
            .font(.tiny)
            .foregroundColor(.blue)
            .frame(width: 35)

            // Charts
            ZStack {
                // Power chart
                Chart {
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
                    AxisMarks(position: .bottom) { value in
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text("\(Int(mins))m")
                            }
                        }
                    }
                }

                // Heart rate chart
                Chart {
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

            // Right Y-axis (HR)
            VStack {
                Text("\(hrRange.upperBound)")
                Spacer()
                Text("\(hrRange.lowerBound)")
            }
            .font(.tiny)
            .foregroundColor(.red)
            .frame(width: 35)
        }
    }
}

#Preview {
    NavigationStack {
        SummaryView(
            viewModel: SummaryViewModel(
                workout: {
                    var workout = Workout(targetPower: 150, targetDuration: 30 * 60)
                    workout.addSample(heartRate: 130, power: 148)
                    workout.addSample(heartRate: 135, power: 152)
                    workout.addSample(heartRate: 140, power: 150)
                    workout.finish()
                    return workout
                }(),
                stravaService: StravaService()
            ),
            onDismiss: {}
        )
    }
}
