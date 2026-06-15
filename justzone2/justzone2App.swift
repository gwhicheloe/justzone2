import SwiftUI
import UIKit

// MARK: - App Delegate (orientation control)

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Screens set this to unlock landscape; all others remain portrait-only.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

@main
struct justzone2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

                    HRZonesView(heartRateService: appState.heartRateService)
                        .tabItem {
                            Label("Zones", systemImage: "heart.text.square")
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
                        .transition(
                            .asymmetric(
                                insertion: .identity,
                                removal: .opacity.combined(with: .scale(scale: 1.06))
                            )
                        )
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

struct SplashView: View {
    @State private var revealed = false
    @State private var landed = false
    @State private var sweep = false
    @State private var breathe = false

    private static let twoFont = Font.custom("ArialRoundedMTBold", size: 228)

    var body: some View {
        ZStack {
            // Deep liquid-emerald backdrop — light drifts slowly beneath the glass.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5],
                        [Float(0.5 + 0.20 * sin(t * 0.45)), Float(0.5 + 0.20 * cos(t * 0.55))],
                        [1, 0.5],
                        [0, 1], [Float(0.5 + 0.16 * cos(t * 0.4)), 1], [1, 1]
                    ],
                    colors: [
                        .black, Color(red: 0, green: 0.12, blue: 0.08), .black,
                        Color(red: 0, green: 0.08, blue: 0.06), Color(red: 0.02, green: 0.27, blue: 0.17), Color(red: 0, green: 0.16, blue: 0.12),
                        .black, Color(red: 0, green: 0.10, blue: 0.07), .black
                    ]
                )
            }
            .ignoresSafeArea()

            // Edge vignette for depth.
            RadialGradient(
                colors: [.clear, .black.opacity(0.6)],
                center: .center, startRadius: 150, endRadius: 470
            )
            .ignoresSafeArea()

            VStack(spacing: 46) {
                ZStack {
                    // Soft ambient halo grounding the digit — no hard edge, it just
                    // breathes gently behind the glass.
                    Circle()
                        .fill(Color(red: 0.05, green: 0.52, blue: 0.30))
                        .frame(width: 250, height: 250)
                        .blur(radius: 80)
                        .opacity(breathe ? 0.5 : 0.28)
                        .scaleEffect(revealed ? 1 : 0.7)

                    heroTwo
                }

                wordmark
                    .opacity(landed ? 1 : 0)
                    .offset(y: landed ? 0 : 16)
            }
            .offset(y: -24)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            // One calm, deliberate entrance: the digit settles into focus —
            // a focus-pull, not a bouncy pop.
            withAnimation(.easeOut(duration: 0.95)) { revealed = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.55)) { landed = true }
            withAnimation(.easeInOut(duration: 1.5).delay(0.7)) { sweep = true }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    /// The hero digit — refined emerald glass: a rich gradient body, a crisp
    /// top specular (not a milky wash), a soft inner shadow for volume, and an
    /// outer glow. Enters by pulling into focus.
    private var heroTwo: some View {
        Text("2")
            .font(Self.twoFont)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.52, green: 0.92, blue: 0.67), location: 0),
                        .init(color: Color(red: 0.13, green: 0.77, blue: 0.44), location: 0.52),
                        .init(color: Color(red: 0.03, green: 0.42, blue: 0.24), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .shadow(.inner(color: .white.opacity(0.7), radius: 1, x: 0, y: 1))
                .shadow(.inner(color: Color(red: 0, green: 0.16, blue: 0.09).opacity(0.7), radius: 9, x: 0, y: -7))
            )
            // Crisp top specular — a thin light catch along the upper curve.
            .overlay {
                GeometryReader { geo in
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: geo.size.width * 1.2, height: geo.size.height * 0.32)
                        .offset(x: -geo.size.width * 0.1, y: -geo.size.height * 0.31)
                        .blur(radius: 2)
                }
                .mask(Text("2").font(Self.twoFont))
                .allowsHitTesting(false)
            }
            // A single, slow light sweep gliding across the digit.
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.28), location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0.4),
                        endPoint: UnitPoint(x: 1, y: 0.6)
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: sweep ? geo.size.width * 1.15 : -geo.size.width * 0.65)
                }
                .mask(Text("2").font(Self.twoFont))
                .allowsHitTesting(false)
            }
            .shadow(color: .green.opacity(0.28), radius: 26)
            .blur(radius: revealed ? 0 : 7)
            .scaleEffect(revealed ? 1.0 : 1.12)
            .opacity(revealed ? 1 : 0)
    }

    private var wordmark: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "figure.outdoor.cycle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                Text("Justzone2")
                    .font(Font.custom("ArialRoundedMTBold", size: 27))
                    .foregroundStyle(.white.opacity(0.95))
            }

            Text("ZONE 2 TRAINING")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .glassEffect(.regular, in: .capsule)
        .overlay {
            // Hairline edge so the glass reads as a real surface.
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
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
    let watchConnectivityService: WatchConnectivityService
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
        let watchConnectivity = WatchConnectivityService()

        self.bluetoothManager = bluetooth
        self.kickrService = kickr
        self.heartRateService = heartRate
        self.stravaService = strava
        self.healthKitManager = healthKit
        self.liveActivityManager = liveActivity
        self.watchConnectivityService = watchConnectivity
        self.setupViewModel = SetupViewModel(
            bluetoothManager: bluetooth,
            kickrService: kickr,
            heartRateService: heartRate,
            stravaService: strava,
            healthKitManager: healthKit,
            liveActivityManager: liveActivity,
            watchConnectivityService: watchConnectivity
        )
        self.historyViewModel = HistoryViewModel(stravaService: strava)
        self.settingsViewModel = SettingsViewModel(stravaService: strava)

        let history = self.historyViewModel
        self.settingsViewModel.onClearData = {
            await history.clearAllData()
        }

        // End any Live Activity left over from a previous killed session.
        liveActivity.endOrphanedActivities()
    }
}
