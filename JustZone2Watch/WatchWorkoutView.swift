import SwiftUI

struct WatchWorkoutView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        Group {
            switch sessionManager.workoutState {
            case "running", "paused":
                workoutActiveView
            case "ended":
                workoutEndedView
            default:
                waitingView
            }
        }
        .task {
            await sessionManager.requestAuthorization()
        }
    }

    // MARK: - Waiting State

    private var waitingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.indoor.cycle")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("JustZone2")
                .font(.headline)
                .foregroundColor(.green)

            Text("Waiting for workout...")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Circle()
                    .fill(sessionManager.isPhoneReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(sessionManager.isPhoneReachable ? "iPhone connected" : "iPhone not reachable")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Active Workout

    private var workoutActiveView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Chunk indicator
                if sessionManager.totalChunks > 0 {
                    Text("Chunk \(sessionManager.currentChunk) of \(sessionManager.totalChunks)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Heart Rate
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(sessionManager.heartRate > 0 ? "\(sessionManager.heartRate)" : "--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Power
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(sessionManager.power > 0 ? "\(sessionManager.power)" : "--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("W")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Chunk time remaining
                Text(sessionManager.formatTime(sessionManager.chunkRemaining))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.green)

                Text("remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Paused indicator
                if sessionManager.workoutState == "paused" {
                    Text("PAUSED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Workout Ended

    private var workoutEndedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("Workout Complete")
                .font(.headline)
                .foregroundColor(.green)
        }
    }
}
