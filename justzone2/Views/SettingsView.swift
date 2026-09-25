import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    private static let stravaOrange = Color(red: 0.99, green: 0.32, blue: 0)

    // Zone 2 target. The zone bounds are written by the Zones tab; reading them
    // through @AppStorage keeps the bpm readout live if the zones change.
    @AppStorage(Zone2Target.key) private var targetFraction = Zone2Target.defaultFraction
    @AppStorage("zone2Min") private var zone2Min = 120
    @AppStorage("zone2Max") private var zone2Max = 140
    @State private var showTargetInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    zone2TargetCard
                    stravaCard
                    diagnosticsSection
                    dataCard
                    websiteCard
                    demoCard
                    aboutCard
                }
                .padding()
                .readableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(tintedBackground)
            .sheet(isPresented: $showTargetInfo) { zone2TargetInfo }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Settings")
                            .font(.custom("ArialRoundedMTBold", size: 28))
                            .foregroundColor(.green)
                        DemoTitleTag()
                    }
                }
            }
        }
    }

    // MARK: - Cards

    private var targetBPM: Int {
        Int(Zone2Target.bpm(zoneMin: zone2Min, zoneMax: zone2Max, fraction: targetFraction).rounded())
    }

    private var zone2TargetCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    iconChip("target", tint: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Zone 2 Target")
                                .font(.subheadline.weight(.semibold))
                            Button { showTargetInfo = true } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("About Zone 2 Target")
                        }
                        Text("Where Zone Targeting holds your heart rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(targetBPM)")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                        Text("BPM")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                    }
                }

                Slider(value: $targetFraction, in: Zone2Target.range, step: 0.05) {
                    Text("Zone 2 target")
                } minimumValueLabel: {
                    Text("Lower").font(.caption2).foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("Upper").font(.caption2).foregroundStyle(.secondary)
                }
                .tint(.green)
                .accessibilityValue("\(targetBPM) beats per minute")
                .sensoryFeedback(.selection, trigger: targetFraction)

                HStack {
                    Text("Zone 2 is \(zone2Min)–\(zone2Max) bpm")
                    Spacer()
                    if abs(targetFraction - Zone2Target.defaultFraction) < 0.001 {
                        Text("Default")
                    } else {
                        Button("Reset to default") {
                            withAnimation { targetFraction = Zone2Target.defaultFraction }
                        }
                        .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var zone2TargetInfo: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Zone 2 is a range, not a single number. Zone Targeting holds your heart rate at one point inside it — this setting chooses which.")

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Upper (the default) keeps you in the top part of Zone 2 — closer to your aerobic threshold, which is where steady Zone 2 rides are usually meant to sit", systemImage: "arrow.up.to.line")
                        Label("It stops a few beats short of the top on purpose, so normal wobble and heart-rate drift over a long ride don't tip you into Zone 3", systemImage: "arrow.up.and.down")
                        Label("Lower makes the ride easier — useful for recovery days, or when you're tired", systemImage: "arrow.down.to.line")
                        Label("Your zones themselves don't change. The chart, the In Zone 2 indicator and your Strava zones all still use the full Zone 2 range", systemImage: "heart.text.square")
                    }
                    .font(.subheadline)

                    Text("The target applies from your next ride, and only when Zone Targeting is switched on. On the workout screen it shows as a white tick on the heart-rate bar.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Zone 2 Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showTargetInfo = false }
                }
            }
        }
    }

    private var stravaCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    iconChip("figure.outdoor.cycle", tint: Self.stravaOrange)
                    Text("Strava")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if viewModel.isStravaConnected {
                        capsuleButton("Disconnect", tint: .red) {
                            viewModel.disconnectStrava()
                        }
                    } else {
                        capsuleButton("Connect", tint: Self.stravaOrange) {
                            Task { await viewModel.connectToStrava() }
                        }
                    }
                }

                // Status on its own full-width row so a long athlete name has
                // room and isn't truncated by the button beside it.
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isStravaConnected ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isStravaConnected ? .green : .secondary)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }

                // Strava's approved attribution wording — also makes the
                // no-affiliation relationship explicit for App Review (4.1).
                Text("Compatible with Strava. JustZone2 is not affiliated with or endorsed by Strava.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusText: String {
        guard viewModel.isStravaConnected else { return "Not connected" }
        if let name = viewModel.stravaAthleteName, !name.isEmpty {
            return "Connected as \(name)"
        }
        return "Connected"
    }

    private var diagnosticsSection: some View {
        DiagnosticsCard()
    }

    private var dataCard: some View {
        SettingsCard {
            Button {
                viewModel.showClearConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    iconChip("trash", tint: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Cached Data")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Remove cached activities and streams")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .confirmationDialog(
            "Clear all cached activities and stream data?",
            isPresented: $viewModel.showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.clearData() }
            }
            Button("Don't Delete", role: .cancel) {}
        }
    }

    private var websiteCard: some View {
        Link(destination: URL(string: "https://www.justzone2.com")!) {
            SettingsCard {
                HStack(spacing: 12) {
                    twoChip
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Website")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("justzone2.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var demoCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                iconChip("play.circle.fill", tint: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo Mode")
                        .font(.subheadline.weight(.semibold))
                    Text("Simulate a trainer & HR strap — try a full workout without hardware")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $viewModel.isDemoMode)
                    .labelsHidden()
            }
        }
    }

    private var aboutCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                iconChip("info.circle.fill", tint: .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Justzone2")
                        .font(.subheadline.weight(.semibold))
                    Text("Zone 2 training, locked in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("v\(appVersion) (\(appBuild))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    if !buildDate.isEmpty {
                        Text(buildDate)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Build number (CFBundleVersion) — increments every TestFlight upload.
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// When this build's binary was produced — a quick "which build am I on?"
    /// stamp, read from the app executable's modification date.
    private var buildDate: String {
        guard let url = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy, HH:mm"
        return fmt.string(from: date)
    }

    // MARK: - Background

    private var tintedBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)
            RadialGradient(
                colors: [Color.green.opacity(0.16), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Shared bits

    @ViewBuilder
    private func capsuleButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }

    private func iconChip(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.16)))
    }

    /// The brand "2" mark in a chip — used where a generic SF Symbol would feel
    /// flat (e.g. the Website link).
    private var twoChip: some View {
        Text("2")
            .font(.custom("ArialRoundedMTBold", size: 20))
            .foregroundStyle(.green)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.green.opacity(0.16)))
    }
}

/// Frosted "liquid glass" card surface, matching the Setup screen.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Diagnostics Card

struct DiagnosticsCard: View {
    @State private var entryCount = DiagnosticsLogger.shared.entryCount
    @State private var showingShareSheet = false
    @State private var showClearConfirmation = false

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diagnostics")
                            .font(.subheadline.weight(.semibold))
                        Text("\(entryCount) log entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                    entryCount = DiagnosticsLogger.shared.entryCount
                }

                HStack(spacing: 10) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Log", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.green.opacity(0.16)))
                            .foregroundStyle(.green)
                    }

                    Button {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear { entryCount = DiagnosticsLogger.shared.entryCount }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(url: DiagnosticsLogger.shared.shareURL)
                .ignoresSafeArea()
        }
        .confirmationDialog("Clear all diagnostic logs?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear Logs", role: .destructive) {
                DiagnosticsLogger.shared.clear()
                entryCount = 0
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    init(items: [Any]) {
        self.items = items
    }

    init(url: URL) {
        self.items = [url]
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// A small blue "demo" tag for a screen's title bar while Demo Mode is on. It
/// lives only in the title, so it never disturbs a screen's layout. Renders
/// nothing in normal use.
struct DemoTitleTag: View {
    @AppStorage("demoMode") private var demoMode = false
    var body: some View {
        if demoMode {
            Text("demo")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(stravaService: StravaService()))
}
