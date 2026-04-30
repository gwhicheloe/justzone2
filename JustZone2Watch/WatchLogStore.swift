import Foundation
import HealthKit
import WatchConnectivity
import os.signpost

/// Thread-safe in-memory log store for the Watch app.
/// Held as a `let` constant on WatchSessionManager so nonisolated methods can append to it.
final class WatchLogStore {
    private let lock = NSLock()
    private var entries: [String] = []
    private let maxEntries = 600

    func append(_ entry: String) {
        lock.withLock {
            entries.append(entry)
            if entries.count > maxEntries { entries.removeFirst() }
        }
    }

    /// Returns all entries joined by newline and clears the store.
    func flush() -> String {
        lock.withLock {
            let text = entries.joined(separator: "\n")
            entries.removeAll()
            return text
        }
    }
}

// MARK: - Signposts (Watch-side, visible in Instruments / Console.app)

let watchSignpostLog = OSLog(subsystem: "com.gwhicheloe.justzone2.watch", category: "comms")

/// Emit an Instruments signpost event from the Watch.
func wsignpost(_ event: String) {
    os_signpost(.event, log: watchSignpostLog, name: "comms", "%{public}s", event)
}

// MARK: - Helpers for human-readable diagnostic output

/// Map HKWorkoutSessionState raw values to readable names.
func hkStateName(_ state: HKWorkoutSessionState) -> String {
    switch state {
    case .notStarted: return "notStarted"
    case .running:    return "running"
    case .ended:      return "ended"
    case .paused:     return "paused"
    case .prepared:   return "prepared"
    case .stopped:    return "stopped"
    @unknown default: return "unknown(\(state.rawValue))"
    }
}

/// One-line snapshot of a Watch-side WCSession's state for diagnostic logs.
/// (Note: watchOS WCSession exposes fewer properties than iOS — no isPaired / isWatchAppInstalled.)
func wcSnapshot(_ session: WCSession) -> String {
    let active = session.activationState == .activated
    return "active=\(active) reachable=\(session.isReachable)"
}
