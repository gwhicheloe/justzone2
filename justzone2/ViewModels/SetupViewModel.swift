import SwiftUI
import Combine

@MainActor
class SetupViewModel: ObservableObject {
    @Published var targetPower: Int = Constants.defaultTargetPower
    @Published var targetDuration: TimeInterval = Constants.defaultDuration
    @Published var isReadyToStart = false
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var discoveredKickrs: [DeviceInfo] = []
    @Published var discoveredHRMonitors: [DeviceInfo] = []
    @Published var kickrConnected = false
    @Published var hrConnected = false
    @Published var kickrConnecting = false
    @Published var hrConnecting = false
    @Published var kickrError: String?
    @Published var hrError: String?

    let bluetoothManager: BluetoothManager
    let kickrService: KickrService
    let heartRateService: HeartRateService
    let stravaService: StravaService

    private var cancellables = Set<AnyCancellable>()

    init(
        bluetoothManager: BluetoothManager,
        kickrService: KickrService,
        heartRateService: HeartRateService,
        stravaService: StravaService
    ) {
        self.bluetoothManager = bluetoothManager
        self.kickrService = kickrService
        self.heartRateService = heartRateService
        self.stravaService = stravaService

        setupBindings()
    }

    private func setupBindings() {
        // Forward Bluetooth state
        bluetoothManager.$isBluetoothEnabled
            .assign(to: &$isBluetoothEnabled)

        bluetoothManager.$isScanning
            .assign(to: &$isScanning)

        bluetoothManager.$discoveredKickrs
            .assign(to: &$discoveredKickrs)

        bluetoothManager.$discoveredHRMonitors
            .assign(to: &$discoveredHRMonitors)

        // Forward service state
        kickrService.$isConnected
            .assign(to: &$isReadyToStart)

        kickrService.$isConnected
            .sink { [weak self] connected in
                self?.kickrConnected = connected
                if connected {
                    self?.kickrConnecting = false
                    self?.stopScanningIfAllConnected()
                }
            }
            .store(in: &cancellables)

        kickrService.$connectionError
            .sink { [weak self] error in
                self?.kickrError = error
                if error != nil {
                    self?.kickrConnecting = false
                }
            }
            .store(in: &cancellables)

        heartRateService.$isConnected
            .sink { [weak self] connected in
                self?.hrConnected = connected
                if connected {
                    self?.hrConnecting = false
                    self?.stopScanningIfAllConnected()
                }
            }
            .store(in: &cancellables)

        heartRateService.$connectionError
            .sink { [weak self] error in
                self?.hrError = error
                if error != nil {
                    self?.hrConnecting = false
                }
            }
            .store(in: &cancellables)
    }

    func startScanning() {
        bluetoothManager.startScanning()
    }

    func stopScanning() {
        bluetoothManager.stopScanning()
    }

    private func stopScanningIfAllConnected() {
        // Stop scanning once KICKR is connected (required device)
        // User can tap Scan again if they need to find more devices
        if kickrConnected {
            stopScanning()
        }
    }

    func connectKickr(_ device: DeviceInfo) {
        kickrConnecting = true
        kickrError = nil
        kickrService.connect(to: device)
    }

    func disconnectKickr() {
        kickrConnecting = false
        kickrService.disconnect()
    }

    func connectHeartRateMonitor(_ device: DeviceInfo) {
        hrConnecting = true
        hrError = nil
        heartRateService.connect(to: device)
    }

    func disconnectHeartRateMonitor() {
        hrConnecting = false
        heartRateService.disconnect()
    }

    func createWorkout() -> Workout {
        Workout(targetPower: targetPower, targetDuration: targetDuration)
    }

    // Power range: 120-200W in 5W increments (Zone 2 range)
    var powerOptions: [Int] {
        stride(from: 120, through: 200, by: 5).map { $0 }
    }

    // Duration range: 5min - 3hrs in 5min increments
    var durationOptions: [TimeInterval] {
        stride(from: 5 * 60, through: 180 * 60, by: 5 * 60).map { TimeInterval($0) }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes) min"
    }
}
