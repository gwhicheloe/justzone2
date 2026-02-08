import SwiftUI

@main
struct JustZone2WatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(sessionManager: sessionManager)
        }
    }
}
