import SwiftUI

struct DeviceRow: View {
    let device: DeviceInfo
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

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
                } else {
                    onConnect()
                }
            }) {
                Text(isConnected ? "Disconnect" : "Connect")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isConnected ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(isConnected ? .red : .blue)
                    .cornerRadius(8)
            }
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
