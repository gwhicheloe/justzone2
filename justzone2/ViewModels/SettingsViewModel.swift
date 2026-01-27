import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var zone2Min: Int {
        didSet { UserDefaults.standard.set(zone2Min, forKey: "zone2Min") }
    }
    @Published var zone2Max: Int {
        didSet { UserDefaults.standard.set(zone2Max, forKey: "zone2Max") }
    }
    @Published var isStravaConnected = false

    let stravaService: StravaService

    init(stravaService: StravaService) {
        self.stravaService = stravaService
        self.zone2Min = UserDefaults.standard.object(forKey: "zone2Min") as? Int ?? 120
        self.zone2Max = UserDefaults.standard.object(forKey: "zone2Max") as? Int ?? 140

        stravaService.$isAuthenticated
            .assign(to: &$isStravaConnected)
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

    // HR range options: 60-200 bpm
    var hrOptions: [Int] {
        Array(60...200)
    }
}
