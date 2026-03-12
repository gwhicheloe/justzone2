import Foundation

/// Thread-safe in-memory log store for the Watch app.
/// Held as a `let` constant on WatchSessionManager so nonisolated methods can append to it.
final class WatchLogStore {
    private let lock = NSLock()
    private var entries: [String] = []
    private let maxEntries = 300

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
