import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    private static let stravaOrange = Color(red: 0.99, green: 0.32, blue: 0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    stravaCard
                    diagnosticsSection
                    dataCard
                    websiteCard
                    aboutCard
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(tintedBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.custom("ArialRoundedMTBold", size: 28))
                        .foregroundColor(.green)
                }
            }
        }
    }

    // MARK: - Cards

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
                    iconChip("safari", tint: .blue)
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
                Text("v\(appVersion)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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

#Preview {
    SettingsView(viewModel: SettingsViewModel(stravaService: StravaService()))
}
