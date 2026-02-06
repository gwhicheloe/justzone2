import CoreBluetooth
import Combine

@MainActor
class HeartRateService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectedDeviceId: UUID?
    @Published var currentHeartRate: Int = 0
    @Published var connectionError: String?

    private weak var bluetoothManager: BluetoothManager?
    private var peripheral: CBPeripheral?
    private var heartRateMeasurementCharacteristic: CBCharacteristic?

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        super.init()
        
        // Register for connection callbacks
        setupConnectionCallbacks()
    }
    
    private func setupConnectionCallbacks() {
        guard let manager = bluetoothManager else { return }
        
        let onConnect = manager.onPeripheralConnected
        let onFailToConnect = manager.onPeripheralFailedToConnect
        let onDisconnect = manager.onPeripheralDisconnected
        
        manager.onPeripheralConnected = { [weak self] peripheral in
            guard let self = self else { return }
            if let existing = onConnect {
                existing(peripheral)
            }
            Task { @MainActor in
                guard peripheral == self.peripheral else { return }
                peripheral.discoverServices([Constants.heartRateService])
            }
        }
        
        manager.onPeripheralFailedToConnect = { [weak self] peripheral, error in
            guard let self = self else { return }
            if let existing = onFailToConnect {
                existing(peripheral, error)
            }
            Task { @MainActor in
                guard peripheral == self.peripheral else { return }
                self.connectionError = error?.localizedDescription ?? "Failed to connect"
                self.cleanup()
            }
        }
        
        manager.onPeripheralDisconnected = { [weak self] peripheral, error in
            guard let self = self else { return }
            if let existing = onDisconnect {
                existing(peripheral, error)
            }
            Task { @MainActor in
                guard peripheral == self.peripheral else { return }
                if let error = error {
                    self.connectionError = "Disconnected: \(error.localizedDescription)"
                }
                self.cleanup()
            }
        }
    }

    func connect(to device: DeviceInfo) {
        guard device.type == .heartRateMonitor else { return }
        connectionError = nil
        peripheral = device.peripheral
        connectedDeviceId = device.id
        peripheral?.delegate = self
        bluetoothManager?.connect(device.peripheral)
    }

    func disconnect() {
        guard let peripheral = peripheral else { return }
        bluetoothManager?.disconnect(peripheral)
        cleanup()
    }

    private func cleanup() {
        isConnected = false
        connectedDeviceId = nil
        currentHeartRate = 0
        peripheral = nil
        heartRateMeasurementCharacteristic = nil
    }
}

extension HeartRateService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                connectionError = "Service discovery failed: \(error.localizedDescription)"
                return
            }

            guard let services = peripheral.services else { return }

            for service in services {
                if service.uuid == Constants.heartRateService {
                    peripheral.discoverCharacteristics([Constants.heartRateMeasurement], for: service)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                connectionError = "Characteristic discovery failed: \(error.localizedDescription)"
                return
            }

            guard let characteristics = service.characteristics else { return }

            for characteristic in characteristics {
                if characteristic.uuid == Constants.heartRateMeasurement {
                    self.heartRateMeasurementCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    isConnected = true
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil, let data = characteristic.value else { return }

            if characteristic.uuid == Constants.heartRateMeasurement {
                parseHeartRateData(data)
            }
        }
    }

    private func parseHeartRateData(_ data: Data) {
        guard !data.isEmpty else { return }

        // Heart Rate Measurement format per Bluetooth spec
        // First byte is flags
        let flags = data[0]

        // Bit 0: Heart Rate Value Format
        // 0 = UINT8, 1 = UINT16
        let is16Bit = (flags & 0x01) != 0

        if is16Bit {
            guard data.count >= 3 else { return }
            currentHeartRate = Int(data[1]) | (Int(data[2]) << 8)
        } else {
            guard data.count >= 2 else { return }
            currentHeartRate = Int(data[1])
        }
    }
}

