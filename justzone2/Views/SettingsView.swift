import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                // Zone 2 Heart Rate Range
                Section {
                    HStack {
                        Text("Min HR")
                        Spacer()
                        Picker("", selection: $viewModel.zone2Min) {
                            ForEach(viewModel.hrOptions, id: \.self) { hr in
                                Text("\(hr) bpm").tag(hr)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120, height: 100)
                        .clipped()
                    }

                    HStack {
                        Text("Max HR")
                        Spacer()
                        Picker("", selection: $viewModel.zone2Max) {
                            ForEach(viewModel.hrOptions, id: \.self) { hr in
                                Text("\(hr) bpm").tag(hr)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120, height: 100)
                        .clipped()
                    }
                } header: {
                    Text("Zone 2 Heart Rate Range")
                } footer: {
                    Text("Set your personal Zone 2 heart rate range for training guidance.")
                }

                // Strava Connection
                Section {
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
                } header: {
                    Text("Strava")
                }

                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(stravaService: StravaService()))
}
