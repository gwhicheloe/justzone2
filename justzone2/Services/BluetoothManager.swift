import CoreBluetooth
import Combine

@MainActor
class BluetoothManager: NSObject, ObservableObject {
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var discoveredKickrs: [DeviceInfo] = []
    @Published var discoveredHRMonitors: [DeviceInfo] = []

    private var centralManager: CBCentralManager!
    private var scanContinuation: CheckedContinuation<Void, Never>?
    
    // Callbacks for connection events
    var onPeripheralConnected: ((CBPeripheral) -> Void)?
    var onPeripheralFailedToConnect: ((CBPeripheral, Error?) -> Void)?
    var onPeripheralDisconnected: ((CBPeripheral, Error?) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func checkBluetoothState() {
        isBluetoothEnabled = centralManager.state == .poweredOn
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        guard !isScanning else { return }

        discoveredKickrs.removeAll()
        discoveredHRMonitors.removeAll()
        isScanning = true

        centralManager.scanForPeripherals(
            withServices: [Constants.ftmsService, Constants.heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
    }

    func connect(_ peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func getPeripheral(_ peripheral: CBPeripheral) -> CBPeripheral {
        peripheral
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let isPoweredOn = central.state == .poweredOn
        Task { @MainActor in
            self.isBluetoothEnabled = isPoweredOn
            if !isPoweredOn {
                self.isScanning = false
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            // Check advertised services
            if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                if serviceUUIDs.contains(Constants.ftmsService) {
                    let device = DeviceInfo(peripheral: peripheral, type: .kickr)
                    if !discoveredKickrs.contains(device) {
                        discoveredKickrs.append(device)
                    }
                }
                if serviceUUIDs.contains(Constants.heartRateService) {
                    let device = DeviceInfo(peripheral: peripheral, type: .heartRateMonitor)
                    if !discoveredHRMonitors.contains(device) {
                        discoveredHRMonitors.append(device)
                    }
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            onPeripheralConnected?(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            onPeripheralFailedToConnect?(peripheral, error)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            onPeripheralDisconnected?(peripheral, error)
        }
    }
}
