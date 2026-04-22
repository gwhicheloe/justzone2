import SwiftUI

/// Detail view for a workout that lives only on this device — either an
/// interrupted in-progress workout or a completed one not yet uploaded
/// to Strava. Provides chart, stats, and an Upload to Strava button.
struct LocalActivityDetailView: View {
    let local: LocalWorkout
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var uploadState: UploadState = .ready
    @State private var showDeleteConfirm = false

    private var chartData: [ChartDataPoint] {
        local.workout.samples.map {
            ChartDataPoint(time: $0.timestamp, heartRate: $0.heartRate, power: $0.power)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: local.status == .inProgress ? "arrow.counterclockwise.circle.fill" : "icloud.and.arrow.up.fill")
            Text(local.status == .inProgress ? "Interrupted workout" : "Not uploaded yet")
        }
        .font(.labelMedium)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(local.status == .inProgress ? Color.orange : Color.strava)
        .cornerRadius(8)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusBadge

                Text(viewModel.formatDate(local.workout.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    statBox(
                        icon: "clock",
                        color: .secondary,
                        value: viewModel.formatDuration(Int(local.elapsedTime)),
                        label: "Duration"
                    )
                    statBox(
                        icon: "bolt.fill",
                        color: .blue,
                        value: local.workout.averagePower.map { "\($0)" } ?? "--",
                        label: "Avg Power"
                    )
                    statBox(
                        icon: "heart.fill",
                        color: .red,
                        value: local.workout.averageHeartRate.map { "\($0)" } ?? "--",
                        label: "Avg HR"
                    )
                }
                .padding(.horizontal)

                if !chartData.isEmpty {
                    MiniChartView(chartData: chartData, targetPower: local.workout.targetPower)
                        .frame(height: 200)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.headlineLarge)
                            .foregroundColor(.secondary)
                        Text("No samples recorded yet")
                            .font(.bodyMedium)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    if viewModel.isStravaConnected {
                        UploadButton(state: uploadState) {
                            uploadState = .processing
                            Task {
                                if let activityId = await viewModel.uploadLocalWorkout(local) {
                                    uploadState = .complete(activityId: activityId)
                                    try? await Task.sleep(nanoseconds: 800_000_000)
                                    dismiss()
                                } else {
                                    uploadState = .failed(message: viewModel.error ?? "Upload failed")
                                }
                            }
                        }
                        .disabled(chartData.isEmpty)
                    } else {
                        Text("Connect Strava in Settings to upload")
                            .font(.labelMedium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Workout")
                        }
                        .font(.bodyMedium)
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Workout")
                    .font(.custom("ArialRoundedMTBold", size: 28))
                    .foregroundColor(.green)
            }
        }
        .alert("Delete this workout?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                viewModel.deleteLocalWorkout(local)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the workout from your device. This cannot be undone.")
        }
    }

    private func statBox(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.labelMedium)
                .foregroundColor(color)
            Text(value)
                .font(.headlineMedium)
            Text(label)
                .font(.labelSmall)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
