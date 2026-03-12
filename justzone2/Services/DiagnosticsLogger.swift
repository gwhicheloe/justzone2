import Foundation

/// Thread-safe persistent diagnostics logger. Callable from any isolation context.
/// Watch-side logs are transferred via WCSession and appended automatically.
final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let lock = NSLock()
    private var entries: [String] = []
    private let maxEntries = 1000

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

    /// Save and return the log file URL — pass directly to UIActivityViewController.
    var shareURL: URL {
        saveToFile()
        return logFileURL
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
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}

/// Convenience free function — callable from any isolation context.
func dlog(_ message: String) {
    DiagnosticsLogger.shared.log(message)
}
