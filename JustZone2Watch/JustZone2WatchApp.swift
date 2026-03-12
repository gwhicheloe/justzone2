import SwiftUI

@main
struct JustZone2WatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(sessionManager: sessionManager)
                .task {
                    // Ensure HealthKit is authorized before any workout starts,
                    // including Mode A sessions that arrive via workoutSessionMirroringStartHandler
                    // without going through the WCSession request-authorization path.
                    await sessionManager.requestAuthorization()
                }
        }
    }
}
