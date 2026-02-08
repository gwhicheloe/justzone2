import SwiftUI
import Combine

@MainActor
class SetupViewModel: ObservableObject {
    @Published var targetPower: Int {
        didSet { UserDefaults.standard.set(targetPower, forKey: "targetPower") }
    }
    @Published var targetDuration: TimeInterval {
        didSet { UserDefaults.standard.set(targetDuration, forKey: "targetDuration") }
    }
    @Published var isReadyToStart = false
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var discoveredKickrs: [DeviceInfo] = []
    @Published var discoveredHRMonitors: [DeviceInfo] = []
    @Published var kickrConnected = false
    @Published var hrConnected = false
    @Published var connectedKickrId: UUID?
    @Published var connectedHRId: UUID?
    @Published var kickrConnecting = false
    @Published var hrConnecting = false
    @Published var kickrError: String?
    @Published var hrError: String?
    @Published var isStravaConnected = false
    @Published var stravaError: String?
    @Published var isHealthKitAuthorized = false
    @Published var healthKitError: String?
    @Published var useWatchHR = false
    @Published var isWatchAvailable = false
    @Published var isWatchReachable = false
    @Published var isWatchAppInstalled = false

    let bluetoothManager: BluetoothManager
    let kickrService: KickrService
    let heartRateService: HeartRateService
    let stravaService: StravaService
    let healthKitManager: HealthKitManager
    let liveActivityManager: LiveActivityManager
    let watchConnectivityService: WatchConnectivityService

    private var cancellables = Set<AnyCancellable>()

    init(
        bluetoothManager: BluetoothManager,
        kickrService: KickrService,
        heartRateService: HeartRateService,
        stravaService: StravaService,
        healthKitManager: HealthKitManager,
        liveActivityManager: LiveActivityManager,
        watchConnectivityService: WatchConnectivityService
    ) {
        self.bluetoothManager = bluetoothManager
        self.kickrService = kickrService
        self.heartRateService = heartRateService
        self.stravaService = stravaService
        self.healthKitManager = healthKitManager
        self.liveActivityManager = liveActivityManager
        self.watchConnectivityService = watchConnectivityService

        let savedPower = UserDefaults.standard.object(forKey: "targetPower") as? Int
        self.targetPower = savedPower ?? Constants.defaultTargetPower

        let savedDuration = UserDefaults.standard.object(forKey: "targetDuration") as? TimeInterval
        self.targetDuration = savedDuration ?? Constants.defaultDuration

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

        kickrService.$connectedDeviceId
            .assign(to: &$connectedKickrId)

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

        heartRateService.$connectedDeviceId
            .assign(to: &$connectedHRId)

        heartRateService.$connectionError
            .sink { [weak self] error in
                self?.hrError = error
                if error != nil {
                    self?.hrConnecting = false
                }
            }
            .store(in: &cancellables)

        stravaService.$isAuthenticated
            .assign(to: &$isStravaConnected)

        // Forward HealthKit authorization state
        healthKitManager.$isAuthorized
            .assign(to: &$isHealthKitAuthorized)

        // Forward Watch availability — show option when a Watch is paired
        watchConnectivityService.$isWatchPaired
            .assign(to: &$isWatchAvailable)

        watchConnectivityService.$isWatchReachable
            .assign(to: &$isWatchReachable)

        watchConnectivityService.$isWatchAppInstalled
            .assign(to: &$isWatchAppInstalled)
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
        // Deselect Watch HR when connecting Bluetooth HR
        useWatchHR = false
        hrConnecting = true
        hrError = nil
        heartRateService.connect(to: device)
    }

    func disconnectHeartRateMonitor() {
        hrConnecting = false
        heartRateService.disconnect()
    }

    func selectWatchHR() {
        useWatchHR = true
        // Disconnect any Bluetooth HR monitor
        heartRateService.disconnect()
        hrConnected = false
        hrConnecting = false
    }

    func deselectWatchHR() {
        useWatchHR = false
    }

    func connectToStrava() async {
        stravaError = nil
        do {
            try await stravaService.authenticate()
        } catch {
            stravaError = error.localizedDescription
        }
    }

    func disconnectStrava() {
        stravaService.logout()
        stravaError = nil
    }

    func requestHealthKitAuthorization() async {
        healthKitError = nil
        do {
            try await healthKitManager.requestAuthorization()
        } catch {
            healthKitError = error.localizedDescription
        }
    }

    func createWorkout() -> Workout {
        Workout(targetPower: targetPower, targetDuration: targetDuration)
    }

    var canStartWorkout: Bool {
        kickrConnected && isHealthKitAuthorized
    }

    var startButtonHelpText: String {
        if !kickrConnected && !isHealthKitAuthorized {
            return "Connect trainer and enable Apple Health"
        } else if !kickrConnected {
            return "Connect your smart trainer to start"
        } else if !isHealthKitAuthorized {
            return "Enable Apple Health to track workouts"
        }
        return ""
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
