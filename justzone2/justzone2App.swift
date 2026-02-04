import SwiftUI

@main
struct justzone2App: App {
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView {
                    SetupView(viewModel: appState.setupViewModel)
                        .tabItem {
                            Label("Workout", systemImage: "figure.outdoor.cycle")
                        }

                    HistoryView(viewModel: appState.historyViewModel)
                        .tabItem {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }

                    SettingsView(viewModel: appState.settingsViewModel)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
                .onOpenURL { url in
                    print("Received URL: \(url)")
                }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

struct SplashView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "figure.outdoor.cycle")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Text("Justzone2")
                    .font(.custom("ArialRoundedMTBold", size: 34))
                    .foregroundColor(.green)

                Text("Zone 2 Training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView()
                    .padding(.top, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Holds all app-level state and services
@MainActor
class AppState: ObservableObject {
    let bluetoothManager: BluetoothManager
    let kickrService: KickrService
    let heartRateService: HeartRateService
    let stravaService: StravaService
    let healthKitManager: HealthKitManager
    let liveActivityManager: LiveActivityManager
    let setupViewModel: SetupViewModel
    let historyViewModel: HistoryViewModel
    let settingsViewModel: SettingsViewModel

    init() {
        let bluetooth = BluetoothManager()
        let kickr = KickrService(bluetoothManager: bluetooth)
        let heartRate = HeartRateService(bluetoothManager: bluetooth)
        let strava = StravaService()
        let healthKit = HealthKitManager()
        let liveActivity = LiveActivityManager()

        self.bluetoothManager = bluetooth
        self.kickrService = kickr
        self.heartRateService = heartRate
        self.stravaService = strava
        self.healthKitManager = healthKit
        self.liveActivityManager = liveActivity
        self.setupViewModel = SetupViewModel(
            bluetoothManager: bluetooth,
            kickrService: kickr,
            heartRateService: heartRate,
            stravaService: strava,
            healthKitManager: healthKit,
            liveActivityManager: liveActivity
        )
        self.historyViewModel = HistoryViewModel(stravaService: strava)
        self.settingsViewModel = SettingsViewModel(stravaService: strava)
    }
}
