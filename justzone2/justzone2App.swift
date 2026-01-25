import SwiftUI

@main
struct justzone2App: App {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var stravaService = StravaService()

    var body: some Scene {
        WindowGroup {
            ContentView(
                bluetoothManager: bluetoothManager,
                stravaService: stravaService
            )
        }
    }
}

struct ContentView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var stravaService: StravaService

    @StateObject private var kickrService: KickrService
    @StateObject private var heartRateService: HeartRateService

    init(bluetoothManager: BluetoothManager, stravaService: StravaService) {
        self.bluetoothManager = bluetoothManager
        self.stravaService = stravaService

        // Initialize services with bluetooth manager
        _kickrService = StateObject(wrappedValue: KickrService(bluetoothManager: bluetoothManager))
        _heartRateService = StateObject(wrappedValue: HeartRateService(bluetoothManager: bluetoothManager))
    }

    var body: some View {
        SetupView(viewModel: SetupViewModel(
            bluetoothManager: bluetoothManager,
            kickrService: kickrService,
            heartRateService: heartRateService,
            stravaService: stravaService
        ))
        .onOpenURL { url in
            // Handle Strava OAuth callback
            handleStravaCallback(url)
        }
    }

    private func handleStravaCallback(_ url: URL) {
        // The ASWebAuthenticationSession handles the callback internally
        // This is here for completeness if needed for deep linking
        print("Received URL: \(url)")
    }
}
