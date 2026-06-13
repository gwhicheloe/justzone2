import SwiftUI

struct WatchWorkoutView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        Group {
            switch sessionManager.workoutState {
            case "armed":
                armedView
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

    // MARK: - Armed (waiting for user to Start)

    /// Shown after the iPhone wakes the Watch for a Mode A workout. The user taps
    /// Start here — starting the session from the foreground Watch app is what
    /// makes HR come up reliably.
    private var armedView: some View {
        VStack(spacing: 10) {
            if sessionManager.hrPermissionDenied {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                Text("Enable Heart Rate\non iPhone first")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
            }

            Button {
                sessionManager.startArmedWorkout()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26))
                    Text("Start")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .tint(.green)

            Text("Start your Zone 2 workout")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Waiting State

    private var buildId: String {
        // Use the app binary's modification date as a build timestamp
        guard let executableURL = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
              let date = attrs[.modificationDate] as? Date else {
            return "b?"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd.HHmm"
        return "b\(formatter.string(from: date))"
    }

    private var waitingView: some View {
        VStack(spacing: 12) {
            if sessionManager.hrPermissionDenied {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)

                Text("Heart Rate\nPermission Required")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)

                Text("iPhone → Health\n→ Apps → JustZone2\n→ Enable Heart Rate")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("2")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.green)

                Text("Waiting for workout...")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Ready")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(buildId)
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))
        }
    }

    // MARK: - Active Workout

    private var workoutActiveView: some View {
        VStack(spacing: 4) {
            // Chunk indicator
            if sessionManager.totalChunks > 0 {
                Text("\(sessionManager.currentChunk)/\(sessionManager.totalChunks)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Heart Rate
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 10))
                Text(sessionManager.heartRate > 0 ? "\(sessionManager.heartRate)" : "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("BPM")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Power
            HStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 10))
                Text(sessionManager.power > 0 ? "\(sessionManager.power)" : "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("W")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Chunk time remaining
            Text(sessionManager.formatTime(sessionManager.chunkRemaining))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.green)

            Text("remaining")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Paused indicator
            if sessionManager.workoutState == "paused" {
                Text("PAUSED")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
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
