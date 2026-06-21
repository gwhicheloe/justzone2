import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isStravaConnected = false
    @Published var stravaAthleteName: String?
    @Published var showClearConfirmation = false

    let stravaService: StravaService
    var onClearData: (() async -> Void)?

    init(stravaService: StravaService) {
        self.stravaService = stravaService

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
