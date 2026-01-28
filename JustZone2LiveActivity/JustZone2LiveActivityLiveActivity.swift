//
//  JustZone2LiveActivityLiveActivity.swift
//  JustZone2LiveActivity
//
//  Created by george whicheloe on 28/01/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct JustZone2LiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(context.state.currentHeartRate)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("bpm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("\(context.state.currentPower)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("W")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.formattedTime)
                            .font(.title)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        if context.state.isPaused {
                            Text("PAUSED")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Target: \(context.attributes.targetPower)W")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Duration: \(context.attributes.formattedTargetDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(context.state.currentHeartRate)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            } compactTrailing: {
                Text(context.state.formattedTime)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.indoor.cycle")
                    .foregroundColor(.green)
            }
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.indoor.cycle")
                    .foregroundColor(.green)
                Text("JustZone2")
                    .font(.headline)
                Spacer()
                if context.state.isPaused {
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

            HStack(spacing: 20) {
                // Elapsed Time
                VStack(spacing: 4) {
                    Text(context.state.formattedTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Heart Rate
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(context.state.currentHeartRate)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Text("bpm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Power
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("\(context.state.currentPower)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Text("watts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(Color.green)
                        .frame(width: progressWidth(geometry: geometry), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Target: \(context.attributes.targetPower)W")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Goal: \(context.attributes.formattedTargetDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.8))
    }

    private func progressWidth(geometry: GeometryProxy) -> CGFloat {
        let progress = min(context.state.elapsedTime / context.attributes.targetDuration, 1.0)
        return geometry.size.width * progress
    }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes(
    workoutStartDate: Date(),
    targetPower: 150,
    targetDuration: 30 * 60
)) {
    JustZone2LiveActivityLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        elapsedTime: 15 * 60,
        currentHeartRate: 135,
        currentPower: 148,
        isPaused: false
    )
    WorkoutActivityAttributes.ContentState(
        elapsedTime: 20 * 60,
        currentHeartRate: 142,
        currentPower: 152,
        isPaused: true
    )
}
