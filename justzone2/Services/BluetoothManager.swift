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

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
}

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            isBluetoothEnabled = central.state == .poweredOn
            if !isBluetoothEnabled {
                isScanning = false
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
        // Connection handled by individual services
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Connection failure handled by individual services
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Disconnection handled by individual services
    }
}
