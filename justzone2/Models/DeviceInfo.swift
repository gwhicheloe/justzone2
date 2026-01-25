import CoreBluetooth

struct DeviceInfo: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let type: DeviceType

    enum DeviceType {
        case kickr
        case heartRateMonitor

        var displayName: String {
            switch self {
            case .kickr:
                return "Smart Trainer"
            case .heartRateMonitor:
                return "Heart Rate Monitor"
            }
        }

        var iconName: String {
            switch self {
            case .kickr:
                return "bicycle"
            case .heartRateMonitor:
                return "heart.fill"
            }
        }
    }

    init(peripheral: CBPeripheral, type: DeviceType) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
        self.type = type
    }

    static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}
