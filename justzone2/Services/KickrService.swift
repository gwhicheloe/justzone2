import CoreBluetooth
import Combine

@MainActor
class KickrService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isControlling = false
    @Published var currentPower: Int = 0
    @Published var targetPower: Int = 0
    @Published var connectionError: String?

    private weak var bluetoothManager: BluetoothManager?
    private var peripheral: CBPeripheral?
    private var controlPointCharacteristic: CBCharacteristic?
    private var indoorBikeDataCharacteristic: CBCharacteristic?

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
                peripheral.discoverServices([Constants.ftmsService])
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
        guard device.type == .kickr else { return }
        connectionError = nil
        peripheral = device.peripheral
        peripheral?.delegate = self
        bluetoothManager?.connect(device.peripheral)
    }

    func disconnect() {
        guard let peripheral = peripheral else { return }
        bluetoothManager?.disconnect(peripheral)
        cleanup()
    }

    func setTargetPower(_ watts: Int) {
        // Always store the target power so it's available when control is granted
        targetPower = watts

        // Only send the command if we're connected and controlling
        guard isConnected, isControlling else { return }
        guard let characteristic = controlPointCharacteristic else { return }
        guard let peripheral = peripheral else { return }

        // FTMS Set Target Power command
        // OpCode: 0x05, followed by target power in watts (little-endian Int16)
        var data = Data([Constants.FTMSOpCode.setTargetPower.rawValue])
        var power = Int16(watts).littleEndian
        withUnsafeBytes(of: &power) { data.append(contentsOf: $0) }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    func startWorkout() {
        guard isConnected else { return }
        requestControl()
    }

    func stopWorkout() {
        guard isConnected, isControlling else { return }
        guard let characteristic = controlPointCharacteristic else { return }
        guard let peripheral = peripheral else { return }

        // Stop command
        let data = Data([Constants.FTMSOpCode.stopOrPause.rawValue, 0x01]) // 0x01 = stop
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        isControlling = false
    }

    private func requestControl() {
        guard let characteristic = controlPointCharacteristic else { return }
        guard let peripheral = peripheral else { return }

        // Request Control
        let data = Data([Constants.FTMSOpCode.requestControl.rawValue])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func startERGMode() {
        guard let characteristic = controlPointCharacteristic else { return }
        guard let peripheral = peripheral else { return }

        // Start or Resume
        let data = Data([Constants.FTMSOpCode.startOrResume.rawValue])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        isControlling = true

        // Set initial target power if we have one
        if targetPower > 0 {
            setTargetPower(targetPower)
        }
    }

    private func cleanup() {
        isConnected = false
        isControlling = false
        currentPower = 0
        peripheral = nil
        controlPointCharacteristic = nil
        indoorBikeDataCharacteristic = nil
    }
}

extension KickrService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                connectionError = "Service discovery failed: \(error.localizedDescription)"
                return
            }

            guard let services = peripheral.services else { return }

            for service in services {
                if service.uuid == Constants.ftmsService {
                    peripheral.discoverCharacteristics([
                        Constants.ftmsControlPoint,
                        Constants.ftmsIndoorBikeData
                    ], for: service)
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
                switch characteristic.uuid {
                case Constants.ftmsControlPoint:
                    self.controlPointCharacteristic = characteristic
                    // Enable indications for control point responses
                    peripheral.setNotifyValue(true, for: characteristic)

                case Constants.ftmsIndoorBikeData:
                    self.indoorBikeDataCharacteristic = characteristic
                    // Subscribe to indoor bike data notifications
                    peripheral.setNotifyValue(true, for: characteristic)

                default:
                    break
                }
            }

            // Check if we have all required characteristics
            if controlPointCharacteristic != nil && indoorBikeDataCharacteristic != nil {
                isConnected = true
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil, let data = characteristic.value else { return }

            switch characteristic.uuid {
            case Constants.ftmsIndoorBikeData:
                parseIndoorBikeData(data)

            case Constants.ftmsControlPoint:
                parseControlPointResponse(data)

            default:
                break
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error {
                connectionError = "Write failed: \(error.localizedDescription)"
            }
        }
    }

    private func parseIndoorBikeData(_ data: Data) {
        guard data.count >= 2 else { return }

        // Indoor Bike Data format per FTMS spec
        // Flags are first 2 bytes (little-endian)
        let flags = UInt16(data[0]) | (UInt16(data[1]) << 8)

        var offset = 2

        // Bit 0: More Data (not present if set, but we handle presence)
        // Bit 1: Average Speed present
        // Bit 2: Instantaneous Cadence present
        // Bit 3: Average Cadence present
        // Bit 4: Total Distance present
        // Bit 5: Resistance Level present
        // Bit 6: Instantaneous Power present

        // Check if Instantaneous Speed is present (bit 0 = 0 means present)
        if (flags & 0x01) == 0 {
            offset += 2 // Skip instantaneous speed (uint16)
        }

        // Average Speed (bit 1)
        if (flags & 0x02) != 0 {
            offset += 2
        }

        // Instantaneous Cadence (bit 2)
        if (flags & 0x04) != 0 {
            offset += 2
        }

        // Average Cadence (bit 3)
        if (flags & 0x08) != 0 {
            offset += 2
        }

        // Total Distance (bit 4) - 3 bytes
        if (flags & 0x10) != 0 {
            offset += 3
        }

        // Resistance Level (bit 5)
        if (flags & 0x20) != 0 {
            offset += 2
        }

        // Instantaneous Power (bit 6)
        if (flags & 0x40) != 0 {
            guard offset + 2 <= data.count else { return }
            let power = Int16(data[offset]) | (Int16(data[offset + 1]) << 8)
            currentPower = Int(power)
        }
    }

    private func parseControlPointResponse(_ data: Data) {
        guard data.count >= 3 else { return }

        // Response format: [Response OpCode (0x80), Request OpCode, Result Code]
        let responseOpCode = data[0]
        let requestOpCode = data[1]
        let resultCode = data[2]

        guard responseOpCode == 0x80 else { return }

        // Result codes: 0x01 = Success, 0x02 = Not Supported, 0x03 = Invalid Parameter, etc.
        if resultCode == 0x01 {
            // Success
            if requestOpCode == Constants.FTMSOpCode.requestControl.rawValue {
                // Control granted, now start ERG mode
                startERGMode()
            }
        } else {
            connectionError = "FTMS command failed with code: \(resultCode)"
        }
    }
}

