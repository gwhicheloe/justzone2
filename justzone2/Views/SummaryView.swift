import SwiftUI

struct SummaryView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                Text("Workout Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Duration",
                        value: viewModel.formatDuration(viewModel.workout.actualDuration),
                        icon: "clock.fill"
                    )

                    StatCard(
                        title: "Avg Power",
                        value: viewModel.workout.averagePower.map { "\($0)W" } ?? "--",
                        icon: "bolt.fill"
                    )

                    StatCard(
                        title: "Avg HR",
                        value: viewModel.workout.averageHeartRate.map { "\($0)" } ?? "--",
                        icon: "heart.fill"
                    )

                    StatCard(
                        title: "Max HR",
                        value: viewModel.workout.maxHeartRate.map { "\($0)" } ?? "--",
                        icon: "heart.fill"
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Strava Section
                VStack(spacing: 16) {
                    Image("strava-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        .opacity(0.8)

                    if !viewModel.isStravaConnected {
                        Button(action: {
                            Task {
                                await viewModel.connectToStrava()
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect to Strava")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    } else {
                        switch viewModel.uploadState {
                        case .idle:
                            Button(action: {
                                Task {
                                    await viewModel.uploadToStrava()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Upload to Strava")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                            }

                        case .uploading:
                            VStack(spacing: 8) {
                                ProgressView(value: viewModel.uploadProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                Text("Uploading...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()

                        case .success:
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Uploaded to Strava!")
                                        .fontWeight(.semibold)
                                }

                                if let url = viewModel.stravaActivityURL {
                                    Link(destination: url) {
                                        HStack {
                                            Text("View on Strava")
                                            Image(systemName: "arrow.up.right.square")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)

                        case .error(let message):
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Upload Failed")
                                        .fontWeight(.semibold)
                                }

                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button("Retry") {
                                    Task {
                                        await viewModel.uploadToStrava()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Done Button
                Button(action: {
                    // Pop to root
                    dismiss()
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Summary")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        SummaryView(viewModel: SummaryViewModel(
            workout: {
                var workout = Workout(targetPower: 150, targetDuration: 30 * 60)
                workout.addSample(heartRate: 130, power: 148)
                workout.addSample(heartRate: 135, power: 152)
                workout.addSample(heartRate: 140, power: 150)
                workout.finish()
                return workout
            }(),
            stravaService: StravaService()
        ))
    }
}
