# JustZone2

A minimal iOS app for Zone 2 training that controls a Wahoo KICKR in ERG mode, records heart rate, and uploads workouts to Strava.

## Tech Stack

- **Platform**: iOS 16+
- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Bluetooth**: CoreBluetooth (FTMS protocol for KICKR, standard HR profile)
- **Auth**: ASWebAuthenticationSession for Strava OAuth
- **Networking**: URLSession

## Project Structure

```
justzone2/
├── justzone2App.swift          # App entry point, environment setup
├── Models/
│   ├── Workout.swift           # Workout data with samples and stats
│   ├── WorkoutSample.swift     # Individual HR/power sample
│   └── DeviceInfo.swift        # BLE device representation
├── Services/
│   ├── BluetoothManager.swift  # CBCentralManager wrapper
│   ├── KickrService.swift      # FTMS ERG mode control
│   ├── HeartRateService.swift  # HR monitor connection
│   └── StravaService.swift     # OAuth + upload
├── ViewModels/
│   ├── SetupViewModel.swift    # Device pairing state
│   ├── WorkoutViewModel.swift  # Active workout logic
│   └── SummaryViewModel.swift  # Post-workout upload
├── Views/
│   ├── SetupView.swift         # Main setup screen
│   ├── WorkoutView.swift       # Active workout display
│   ├── SummaryView.swift       # Results + Strava upload
│   └── Components/
│       ├── DeviceRow.swift
│       ├── PowerPicker.swift
│       └── DurationPicker.swift
├── Utilities/
│   ├── Constants.swift         # BLE UUIDs, Strava config
│   └── FITEncoder.swift        # TCX file generation
└── Resources/
    ├── Info.plist
    └── Assets.xcassets/
```

## Key Bluetooth UUIDs

```swift
// FTMS (Fitness Machine Service) - Smart Trainers
ftmsService = "1826"
ftmsControlPoint = "2AD9"      // Write ERG commands
ftmsIndoorBikeData = "2AD2"    // Read power data

// Heart Rate Service
heartRateService = "180D"
heartRateMeasurement = "2A37"
```

## FTMS Control Commands

- `0x00` - Request Control
- `0x05 + Int16` - Set Target Power (watts, little-endian)
- `0x07` - Start/Resume
- `0x08 + 0x01` - Stop

## Configuration Required

Before running, update `Constants.swift`:
```swift
static let stravaClientId = "YOUR_CLIENT_ID"
static let stravaClientSecret = "YOUR_CLIENT_SECRET"
```

Register your app at https://www.strava.com/settings/api with callback domain `justzone2`.

## Testing Notes

- **Bluetooth requires physical device** - Simulator doesn't support BLE
- KICKR should appear in device list when powered on
- ERG mode sets resistance to maintain target power regardless of cadence
- Strava uploads use TCX format with power extension data

## Architecture Patterns

- **MVVM**: ViewModels own business logic, Views are declarative
- **@MainActor**: All UI-bound classes use main actor isolation
- **Combine**: Published properties for reactive updates
- **CBPeripheralDelegate**: Async BLE operations via delegate callbacks wrapped in Task
