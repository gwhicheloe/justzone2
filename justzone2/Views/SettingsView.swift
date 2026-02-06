import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Zone 2 Heart Rate Range
                HStack(spacing: 8) {
                    VStack {
                        Text("Min HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.zone2Min) {
                            ForEach(viewModel.hrOptions, id: \.self) { hr in
                                Text("\(hr)").tag(hr)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("Max HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.zone2Max) {
                            ForEach(viewModel.hrOptions, id: \.self) { hr in
                                Text("\(hr)").tag(hr)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // Strava Connection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Strava")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Image(systemName: viewModel.isStravaConnected ? "checkmark.circle.fill" : "link.circle")
                            .foregroundColor(viewModel.isStravaConnected ? .green : .orange)
                        Text(viewModel.isStravaConnected ? "Connected" : "Not connected")
                            .foregroundColor(viewModel.isStravaConnected ? .primary : .secondary)
                        Spacer()
                        if viewModel.isStravaConnected {
                            Button("Disconnect") {
                                viewModel.disconnectStrava()
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Connect") {
                                Task {
                                    await viewModel.connectToStrava()
                                }
                            }
                        }
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // Data
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Button {
                        viewModel.showClearConfirmation = true
                    } label: {
                        HStack {
                            Text("Clear Cached Data")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .confirmationDialog(
                    "Clear all cached activities and stream data?",
                    isPresented: $viewModel.showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.clearData()
                        }
                    }
                    Button("Don't Delete", role: .cancel) {}
                }

                // App Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.custom("ArialRoundedMTBold", size: 28))
                        .foregroundColor(.green)
                }
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(stravaService: StravaService()))
}
