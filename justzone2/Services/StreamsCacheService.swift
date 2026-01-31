import Foundation

/// File-based cache for activity stream data
/// Uses actor for thread-safe file operations
actor StreamsCacheService {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Directory for storing stream cache files
    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("ActivityStreams", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }

        return cacheDir
    }

    /// File URL for a specific activity's streams
    private func fileURL(for activityId: Int) -> URL {
        cacheDirectory.appendingPathComponent("\(activityId).json")
    }

    /// Check if streams exist in cache for an activity
    func hasStreams(for activityId: Int) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: activityId).path)
    }

    /// Load streams from cache for an activity
    func loadStreams(for activityId: Int) -> ActivityStreams? {
        let url = fileURL(for: activityId)

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? decoder.decode(ActivityStreams.self, from: data)
    }

    /// Save streams to cache
    func saveStreams(_ streams: ActivityStreams) {
        let url = fileURL(for: streams.activityId)

        guard let data = try? encoder.encode(streams) else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    /// Clear all cached streams
    func clearCache() {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else { return }

        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get total size of cache in bytes
    func cacheSize() -> Int64 {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else { return 0 }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
}
