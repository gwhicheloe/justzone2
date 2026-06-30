import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isStravaConnected = false
    @Published var stravaAthleteName: String?
    @Published var showClearConfirmation = false

    /// Demo Mode: simulate a connected trainer + HR strap so the whole app can be
    /// used (and reviewed) without hardware. Persisted; `onDemoModeChange` lets
    /// `AppState` start/stop the sensor simulation. Off for normal use.
    @Published var isDemoMode: Bool {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: "demoMode")
            onDemoModeChange?(isDemoMode)
        }
    }
    var onDemoModeChange: ((Bool) -> Void)?

    let stravaService: StravaService
    var onClearData: (() async -> Void)?

    init(stravaService: StravaService) {
        self.stravaService = stravaService
        self.isDemoMode = UserDefaults.standard.bool(forKey: "demoMode")

        stravaService.$isAuthenticated
            .assign(to: &$isStravaConnected)

        stravaService.$athleteName
            .assign(to: &$stravaAthleteName)
    }

    func connectToStrava() async {
        do {
            try await stravaService.authenticate()
        } catch {
            // Error handled silently
        }
    }

    func disconnectStrava() {
        stravaService.logout()
    }

    func clearData() async {
        await onClearData?()
    }
}
