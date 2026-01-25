import SwiftUI

struct DeviceRow: View {
    let device: DeviceInfo
    let isConnected: Bool
    var isConnecting: Bool = false
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    private var buttonText: String {
        if isConnected {
            return "Connected"
        } else if isConnecting {
            return "Connecting..."
        } else {
            return "Connect"
        }
    }

    private var buttonBackground: Color {
        if isConnected {
            return Color.green.opacity(0.1)
        } else if isConnecting {
            return Color.gray.opacity(0.1)
        } else {
            return Color.blue.opacity(0.1)
        }
    }

    private var buttonForeground: Color {
        if isConnected {
            return .green
        } else if isConnecting {
            return .gray
        } else {
            return .blue
        }
    }

    var body: some View {
        HStack {
            Image(systemName: device.type.iconName)
                .foregroundColor(isConnected ? .green : .secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                Text(device.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                if isConnected {
                    onDisconnect()
                } else if !isConnecting {
                    onConnect()
                }
            }) {
                HStack(spacing: 4) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                    }
                    Text(buttonText)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(buttonBackground)
                .foregroundColor(buttonForeground)
                .cornerRadius(8)
            }
            .disabled(isConnecting)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        // Note: Preview requires mock data since CBPeripheral can't be instantiated directly
        Text("DeviceRow Preview")
    }
}
