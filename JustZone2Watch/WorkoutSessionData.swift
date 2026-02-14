import Foundation

/// Data sent from iPhone to Watch via the mirrored workout session's sendData API.
/// Used in Mode A (Watch HR with session mirroring).
struct PhoneToWatchData: Codable {
    let power: Int
    let elapsedTime: TimeInterval
    let chunkRemaining: TimeInterval
    let currentChunk: Int
    let totalChunks: Int
    let adjustedPower: Int
    let targetPower: Int
    let state: String // "running", "paused", "ended"
}
