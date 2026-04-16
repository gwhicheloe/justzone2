import SwiftUI

struct DeviceRow: View {
    let device: DeviceInfo
    let isConnected: Bool
    var isConnecting: Bool = false
    var batteryLevel: Int? = nil
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

            Text(device.name)
                .font(.subheadline)
                .lineLimit(1)

            if let battery = batteryLevel {
                HStack(spacing: 2) {
                    Image(systemName: batteryIconName(for: battery))
                    Text("\(battery)%")
                }
                .font(.caption2)
                .foregroundColor(batteryColor(for: battery))
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
                            .font(.labelMedium)
                    }
                    Text(buttonText)
                        .font(.bodyMedium)
                        .lineLimit(1)
                        .fixedSize()
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

    private func batteryColor(for level: Int) -> Color {
        if level < 10 { return .red }
        if level < 30 { return .orange }
        return .green
    }

    private func batteryIconName(for level: Int) -> String {
        if level < 13 { return "battery.0percent" }
        if level < 38 { return "battery.25percent" }
        if level < 63 { return "battery.50percent" }
        if level < 88 { return "battery.75percent" }
        return "battery.100percent"
    }
}

#Preview {
    VStack {
        // Note: Preview requires mock data since CBPeripheral can't be instantiated directly
        Text("DeviceRow Preview")
    }
}
