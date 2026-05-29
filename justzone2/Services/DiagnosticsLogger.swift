import Foundation
import HealthKit
import WatchConnectivity
import os
import os.signpost

/// Thread-safe persistent diagnostics logger. Callable from any isolation context.
/// Watch-side logs are transferred via WCSession and appended automatically.
final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let lock = NSLock()
    private var entries: [String] = []
    private let maxEntries = 1000

    /// OSLog channel for Instruments / Console.app signposts.
    static let signpostLog = OSLog(subsystem: "com.gwhicheloe.justzone2", category: "comms")

    private init() {
        loadFromFile()
    }

    // MARK: - Logging

    func log(_ message: String) {
        let entry = "[\(Self.timestamp())] \(message)"
        print(entry)
        lock.withLock {
            entries.append(entry)
            if entries.count > maxEntries { entries.removeFirst() }
        }
        saveToFileAsync()
    }

    /// Append a block of Watch-side log lines received via WCSession.
    func appendWatchLog(_ text: String) {
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        let ts = Self.timestamp()
        lock.withLock {
            entries.append("[\(ts)] ──── WATCH LOG ────")
            entries.append(contentsOf: lines)
            entries.append("[\(ts)] ──── END WATCH LOG ────")
            if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        }
        saveToFileAsync()
    }

    // MARK: - Access

    var entryCount: Int { lock.withLock { entries.count } }

    func recentLines(_ n: Int = 50) -> String {
        lock.withLock {
            entries.suffix(n).joined(separator: "\n")
        }
    }

    func clear() {
        lock.withLock { entries.removeAll() }
        saveToFileAsync()
    }

    /// Save and return a dated copy of the log — pass directly to
    /// UIActivityViewController. Exporting under a date/time-stamped filename
    /// means successive exports don't overwrite each other.
    var shareURL: URL {
        saveToFile()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        let name = "justzone2_diagnostics_\(f.string(from: Date())).txt"
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: exportURL)
        try? FileManager.default.copyItem(at: logFileURL, to: exportURL)
        return exportURL
    }

    // MARK: - Persistence

    private var logFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("justzone2_diagnostics.txt")
    }

    private func loadFromFile() {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return }
        entries = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func saveToFileAsync() {
        DispatchQueue.global(qos: .utility).async { [weak self] in self?.saveToFile() }
    }

    @discardableResult
    private func saveToFile() -> Bool {
        let text = lock.withLock { entries.joined(separator: "\n") }
        return (try? text.write(to: logFileURL, atomically: true, encoding: .utf8)) != nil
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}

// MARK: - Free functions (callable from any isolation context)

/// Append a line to the persistent diagnostics log.
func dlog(_ message: String) {
    DiagnosticsLogger.shared.log(message)
}

/// Emit an Instruments signpost event under the "comms" category.
/// Visible in Console.app and Instruments → Points of Interest.
func dsignpost(_ event: String) {
    os_signpost(.event, log: DiagnosticsLogger.signpostLog, name: "comms", "%{public}s", event)
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

/// One-line snapshot of an iPhone-side WCSession's state for diagnostic logs.
func wcSnapshot(_ session: WCSession) -> String {
    let active = session.activationState == .activated
    return "active=\(active) reachable=\(session.isReachable) paired=\(session.isPaired) installed=\(session.isWatchAppInstalled)"
}
