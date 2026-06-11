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
    @State private var emerged = false
    @State private var landed = false
    @State private var pulse = false
    @State private var haloSpin = false
    @State private var shine = false
    @State private var glossDrift = false

    private static let twoFont = Font.custom("ArialRoundedMTBold", size: 240)

    var body: some View {
        ZStack {
            // Liquid backdrop — two mesh points drift slowly so the light
            // appears to flow under the glass.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5],
                        [Float(0.5 + 0.28 * sin(t * 0.7)), Float(0.5 + 0.28 * cos(t * 0.9))],
                        [1, 0.5],
                        [0, 1], [Float(0.5 + 0.22 * cos(t * 0.55)), 1], [1, 1]
                    ],
                    colors: [
                        .black, Color(red: 0, green: 0.16, blue: 0.10), .black,
                        Color(red: 0, green: 0.10, blue: 0.07), Color(red: 0.03, green: 0.33, blue: 0.20), Color(red: 0, green: 0.22, blue: 0.17),
                        .black, Color(red: 0, green: 0.13, blue: 0.08), .black
                    ]
                )
            }
            .ignoresSafeArea()

            // Edge vignette for depth.
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center, startRadius: 170, endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                ZStack {
                    // The hole the 2 erupts from — a dark recess with a faint
                    // emerald glow rising at its outer edge.
                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.62),
                                    .init(color: Color(red: 0.02, green: 0.18, blue: 0.11), location: 0.88),
                                    .init(color: .clear, location: 1)
                                ],
                                center: .center, startRadius: 0, endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)

                    // Machined rim: light catches the top edge, falls away below.
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.30), .white.opacity(0.05), .clear],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 190, height: 190)

                    // Pulse rings radiating from the hole, like a heartbeat.
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.green.opacity(0.35), lineWidth: 0.8)
                            .frame(width: 190, height: 190)
                            .scaleEffect(pulse ? 2.4 : 1.0)
                            .opacity(pulse ? 0 : 0.5)
                            .animation(
                                .easeOut(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.55),
                                value: pulse
                            )
                    }

                    // Orbiting light around the rim of the hole.
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.clear, .green.opacity(0.5), .mint.opacity(0.8), .clear],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 190, height: 190)
                        .blur(radius: 2)
                        .rotationEffect(.degrees(haloSpin ? 360 : 0))

                    // The hero: a big 2 zooming out of the hole to the foreground.
                    // Inner shadows give it gel-like depth: lit top bevel, shaded
                    // lower body, then a hard drop onto the hole behind it.
                    Text("2")
                        .font(Self.twoFont)
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.70, green: 1.0, blue: 0.80), location: 0),
                                    .init(color: Color(red: 0.12, green: 0.88, blue: 0.45), location: 0.48),
                                    .init(color: Color(red: 0.03, green: 0.56, blue: 0.30), location: 1)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                            .shadow(.inner(color: .white.opacity(0.9), radius: 2, x: 0, y: 3))
                            .shadow(.inner(color: Color(red: 0, green: 0.24, blue: 0.11).opacity(0.8), radius: 12, x: 0, y: -10))
                            .shadow(.drop(color: .black.opacity(0.65), radius: 16, x: 0, y: 16))
                        )
                        .shadow(color: .green.opacity(emerged ? 0.4 : 0), radius: 30)
                        .overlay {
                            // Liquid-glass sheen: a wide ellipse of light whose
                            // bottom edge curves through the digit's midriff,
                            // like light refracting through the top of the glass.
                            GeometryReader { geo in
                                Ellipse()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.5), .white.opacity(0.04)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .frame(width: geo.size.width * 1.4, height: geo.size.height * 0.62)
                                    .offset(
                                        x: -geo.size.width * 0.2 + (glossDrift ? 8 : -8),
                                        y: -geo.size.height * 0.18 + (glossDrift ? 5 : -5)
                                    )
                            }
                            .mask(Text("2").font(Self.twoFont))
                            .allowsHitTesting(false)
                        }
                        .overlay {
                            // A band of light gliding across the digit once it lands.
                            GeometryReader { geo in
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.35), location: 0.5),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: UnitPoint(x: 0, y: 0.35),
                                    endPoint: UnitPoint(x: 1, y: 0.65)
                                )
                                .frame(width: geo.size.width * 0.6)
                                .offset(x: shine ? geo.size.width : -geo.size.width * 0.6)
                            }
                            .mask(Text("2").font(Self.twoFont))
                            .allowsHitTesting(false)
                        }
                        // Depth of field: sharpens as it reaches the foreground.
                        .blur(radius: emerged ? 0 : 12)
                        .animation(.easeOut(duration: 0.6).delay(0.15), value: emerged)
                        .scaleEffect(emerged ? 1.0 : 0.03)
                        .opacity(emerged ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.62).delay(0.15), value: emerged)
                }

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
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .glassEffect(.regular, in: .capsule)
                .overlay {
                    // Hairline edge so the glass reads as a real surface.
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .opacity(landed ? 1 : 0)
                .offset(y: landed ? 0 : 24)
            }
            .offset(y: -30)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            emerged = true
            withAnimation(.easeOut(duration: 0.5).delay(0.75)) {
                landed = true
            }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                haloSpin = true
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.9)) {
                shine = true
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glossDrift = true
            }
            pulse = true
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
