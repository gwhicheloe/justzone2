import SwiftUI

@main
struct justzone2App: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SetupView(viewModel: appState.setupViewModel)
                .onOpenURL { url in
                    print("Received URL: \(url)")
                }
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
    let setupViewModel: SetupViewModel

    init() {
        let bluetooth = BluetoothManager()
        let kickr = KickrService(bluetoothManager: bluetooth)
        let heartRate = HeartRateService(bluetoothManager: bluetooth)
        let strava = StravaService()

        self.bluetoothManager = bluetooth
        self.kickrService = kickr
        self.heartRateService = heartRate
        self.stravaService = strava
        self.setupViewModel = SetupViewModel(
            bluetoothManager: bluetooth,
            kickrService: kickr,
            heartRateService: heartRate,
            stravaService: strava
        )
    }
}
