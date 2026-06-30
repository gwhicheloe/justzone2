import CoreBluetooth
import Combine

@MainActor
class HeartRateService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectedDeviceId: UUID?
    @Published var currentHeartRate: Int = 0
    @Published var batteryLevel: Int?
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
                peripheral.discoverServices([Constants.heartRateService, Constants.batteryService])
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

    // MARK: - Demo Mode simulation
    //
    // A self-contained simulated HR strap for Demo Mode. It reports "connected"
    // and streams a realistic in-zone heart rate via the same `@Published`
    // outputs the BLE path uses, so nothing downstream knows the strap isn't
    // real. Started/stopped only by `AppState.applyDemoMode`.
    private var simTimer: AnyCancellable?
    private var simHeartRate: Double = 0
    private static let simulatedDeviceID = UUID(uuidString: "5111110A-DE70-4DE7-0000-000000000002")!

    func startSimulation() {
        guard simTimer == nil else { return }
        connectionError = nil
        connectedDeviceId = Self.simulatedDeviceID
        batteryLevel = 100
        simHeartRate = Double(max(zone2Bounds.min - 8, 70))   // a touch below zone, eases in
        currentHeartRate = Int(simHeartRate)
        isConnected = true
        simTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.simulationTick() }
    }

    func stopSimulation() {
        guard simTimer != nil else { return }
        simTimer?.cancel(); simTimer = nil
        cleanup()
    }

    private func simulationTick() {
        let mid = Double(zone2Bounds.min + zone2Bounds.max) / 2.0
        simHeartRate += (mid - simHeartRate) * 0.05 + Double.random(in: -0.8...0.8)
        currentHeartRate = max(50, Int(simHeartRate.rounded()))
    }

    /// Saved Zone 2 bounds (falling back to 120–140) so simulated HR sits in-zone.
    private var zone2Bounds: (min: Int, max: Int) {
        let lo = UserDefaults.standard.integer(forKey: "zone2Min")
        let hi = UserDefaults.standard.integer(forKey: "zone2Max")
        return (lo > 0 ? lo : 120, hi > 0 ? hi : 140)
    }

    private func cleanup() {
        isConnected = false
        connectedDeviceId = nil
        currentHeartRate = 0
        batteryLevel = nil
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
                } else if service.uuid == Constants.batteryService {
                    peripheral.discoverCharacteristics([Constants.batteryLevel], for: service)
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
                } else if characteristic.uuid == Constants.batteryLevel {
                    peripheral.readValue(for: characteristic)
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil, let data = characteristic.value else { return }

            if characteristic.uuid == Constants.heartRateMeasurement {
                parseHeartRateData(data)
            } else if characteristic.uuid == Constants.batteryLevel {
                guard !data.isEmpty else { return }
                batteryLevel = Int(data[0])
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

