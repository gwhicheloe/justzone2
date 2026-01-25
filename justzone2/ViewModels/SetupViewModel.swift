import SwiftUI
import Combine

@MainActor
class SetupViewModel: ObservableObject {
    @Published var targetPower: Int = Constants.defaultTargetPower
    @Published var targetDuration: TimeInterval = Constants.defaultDuration
    @Published var isReadyToStart = false

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
        // Ready to start when KICKR is connected
        kickrService.$isConnected
            .assign(to: &$isReadyToStart)
    }

    func startScanning() {
        bluetoothManager.startScanning()
    }

    func stopScanning() {
        bluetoothManager.stopScanning()
    }

    func connectKickr(_ device: DeviceInfo) {
        kickrService.connect(to: device)
    }

    func disconnectKickr() {
        kickrService.disconnect()
    }

    func connectHeartRateMonitor(_ device: DeviceInfo) {
        heartRateService.connect(to: device)
    }

    func disconnectHeartRateMonitor() {
        heartRateService.disconnect()
    }

    func createWorkout() -> Workout {
        Workout(targetPower: targetPower, targetDuration: targetDuration)
    }

    // Power range: 50-300W in 5W increments
    var powerOptions: [Int] {
        stride(from: 50, through: 300, by: 5).map { $0 }
    }

    // Duration range: 15min - 3hrs in 5min increments
    var durationOptions: [TimeInterval] {
        stride(from: 15 * 60, through: 180 * 60, by: 5 * 60).map { TimeInterval($0) }
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
