# JustZone2

A minimal iOS app for Zone 2 training that controls a Wahoo KICKR in ERG mode, records heart rate, and uploads workouts to Strava.

## Design Principals

- **Minimal**: The app should be as simple as possible, with no frills or distractions.
- **Intuitive**: The app should be easy to use, with clear instructions and feedback.
- **Robust**: The bluetooth connection should be reliable as possible. A drop out during a workout is terrible.
- **Coding Standard**: The App should pass an Apple code review and use best practices and the appropriate libraries - remember this is a workout app.
- **Professional**: The app should be professional and polished, with a modern look and feel.
- **Performance**: The app should be fast and responsive, with minimal lag or delay.

## Tech Stack

- **Platform**: iOS 26+
- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Bluetooth**: CoreBluetooth (FTMS protocol for KICKR, standard HR profile)
- **Health**: HealthKit (HKWorkoutSession for background execution, saves to Apple Health)
- **Live Activities**: ActivityKit (lock screen visibility during workouts)
- **Auth**: ASWebAuthenticationSession for Strava OAuth
- **Networking**: URLSession
- **Backend**: Cloudflare Workers (secure Strava token exchange)

## Project Structure

```
justzone2/
├── justzone2App.swift          # App entry point, environment setup
├── Models/
│   ├── Workout.swift           # Workout data with samples and stats
│   ├── WorkoutSample.swift     # Individual HR/power sample
│   ├── DeviceInfo.swift        # BLE device representation
│   └── WorkoutActivityAttributes.swift  # Live Activity data model
├── Services/
│   ├── BluetoothManager.swift  # CBCentralManager wrapper
│   ├── KickrService.swift      # FTMS ERG mode control
│   ├── HeartRateService.swift  # HR monitor connection
│   ├── StravaService.swift     # OAuth + upload (uses Cloudflare Worker)
│   ├── HealthKitManager.swift  # HKWorkoutSession management
│   └── LiveActivityManager.swift  # Lock screen Live Activity
├── ViewModels/
│   ├── SetupViewModel.swift    # Device pairing state
│   ├── WorkoutViewModel.swift  # Active workout logic
│   ├── SummaryViewModel.swift  # Post-workout upload
│   ├── HistoryViewModel.swift  # Strava activity history
│   └── SettingsViewModel.swift # App settings
├── Views/
│   ├── SetupView.swift         # Main setup screen
│   ├── WorkoutView.swift       # Active workout display
│   ├── SummaryView.swift       # Results + Strava upload
│   ├── HistoryView.swift       # Activity history + graph
│   ├── SettingsView.swift      # Settings screen
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

JustZone2LiveActivity/          # Widget extension for Live Activities
├── WorkoutActivityAttributes.swift
├── JustZone2LiveActivityBundle.swift
└── JustZone2LiveActivityLiveActivity.swift

cloudflare-worker/              # Strava auth backend (see Security section)
├── src/index.js
├── wrangler.toml
├── package.json
└── README.md
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

## Strava Authentication Security

**The Strava client secret is NOT in the iOS app.** Token exchange is handled by a Cloudflare Worker.

### How it works

1. App opens Strava OAuth in browser (client ID is public, that's fine)
2. User authorizes, Strava redirects back with authorization code
3. App sends code to **Cloudflare Worker** (not Strava)
4. Worker exchanges code for tokens using the secret (stored in Cloudflare)
5. Worker returns tokens to app
6. App stores tokens in Keychain, never sees the secret

### Cloudflare Worker Setup

The worker is deployed at: `https://justzone2-strava-auth.george-whicheloe.workers.dev`

**To deploy/update the worker:**

```bash
cd cloudflare-worker
npm install
npx wrangler login          # First time only - authenticates with Cloudflare
npx wrangler secret put STRAVA_CLIENT_ID
npx wrangler secret put STRAVA_CLIENT_SECRET
npx wrangler deploy
```

**Worker endpoints:**
- `POST /token` - Exchange auth code for tokens (`{"code": "..."}`)
- `POST /refresh` - Refresh expired tokens (`{"refresh_token": "..."}`)

**If you need to rotate the Strava secret:**
1. Generate new secret at https://www.strava.com/settings/api
2. Update worker: `npx wrangler secret put STRAVA_CLIENT_SECRET`
3. No app changes needed

### Strava App Registration

Register at https://www.strava.com/settings/api:
- Authorization Callback Domain: `justzone2`
- The client ID is in `Constants.swift` (public, safe to commit)
- The client secret is ONLY in Cloudflare (never in the app or git)

## HealthKit Integration

Workouts use `HKWorkoutSession` for:
- Reliable background execution (app keeps running when screen locks)
- Green workout indicator in status bar
- Workouts saved to Apple Health (appear in Fitness app)
- HR and power samples recorded to HealthKit

**Required entitlements:** HealthKit capability with Background Delivery enabled.

## Live Activities

During workouts, a Live Activity shows on the lock screen and Dynamic Island:
- Elapsed time
- Current heart rate
- Current power
- Progress bar toward target duration

The Live Activity extension is in `JustZone2LiveActivity/`.

## Testing Notes

- **Bluetooth requires physical device** - Simulator doesn't support BLE
- **Live Activities** - Best tested on physical device (simulator has issues)
- KICKR should appear in device list when powered on
- ERG mode sets resistance to maintain target power regardless of cadence
- Strava uploads use TCX format with power extension data

## Architecture Patterns

- **MVVM**: ViewModels own business logic, Views are declarative
- **@MainActor**: All UI-bound classes use main actor isolation
- **Combine**: Published properties for reactive updates
- **CBPeripheralDelegate**: Async BLE operations via delegate callbacks wrapped in Task

## Current State (Apr 2026)

### Features
- **History tab** - Zone 2 activities from Strava with list and graph views
- **Activity detail view** - Individual activity with HR/power chart, prev/next navigation
- **Graph view** - Domain-based zooming with pinch gesture, anchored to most recent data
- **Settings tab** - Zone 2 HR range pickers, Strava connect/disconnect, diagnostics log share
- **HealthKit** - Workouts save to Apple Health with HR and power data
- **Live Activities** - Lock screen and Dynamic Island visibility during workouts
- **Secure auth** - Strava client secret handled by Cloudflare Worker
- **Apple Watch** - Mode A (Watch HR via HealthKit mirroring) and Mode B (BLE strap, Watch as display)
- **Strava enrichment** - Distance, speed, cadence and correct calories in TCX uploads
- **On-device diagnostics** - Persistent log file shareable from Settings; Watch logs sent to iPhone at workout end
- **PID zone targeting** - Automatic power adjustment to keep HR in Zone 2 using PID controller
- **Auto-complete** - Workout auto-completes when duration reached; warm-up and cool-down phases

### Watch Modes

**Mode A** — Watch measures HR via HealthKit mirrored session. iPhone calls `startWatchApp(with: .indoor)`. Watch records HR samples and sends to iPhone via the mirrored session channel.

**Mode B** — BLE HR strap on iPhone, Watch is display-only. iPhone calls `startWatchApp(with: .outdoor)`. Watch detects `.outdoor` locationType and starts a display-only session (no builder). iPhone pushes updates via WCSession `sendMessage`.

**Key reliability patterns**:
- `mirroringEstablished` flag on `WatchSessionManager`. WCSession display-update guard only fires when mirroring is confirmed working. If mirroring fails silently, Watch accepts WCSession fallback updates instead of blocking them.
- `isStartingWorkout` flag prevents duplicate session starts when mirroring handler, sendMessage, and transferUserInfo all fire simultaneously.
- WCSession HR fallback: when mirroring isn't established, Watch sends HR via `WCSession.sendMessage` → iPhone's `WatchConnectivityService.fallbackHeartRate` → `WorkoutViewModel` merges with `combineLatest`.

**Watch HR data flow** (Mode A):
1. `HKLiveWorkoutDataSource` collects HR via `workoutBuilder(didCollectDataOf:)` (requires HR write permission)
2. `HKAnchoredObjectQuery` reads HR directly from HealthKit as backup
3. HR sent to iPhone via mirrored session (`sendToRemoteWorkoutSession`) or WCSession fallback
4. Watch detects denied HR permission (`authorizationStatus == .sharingDenied`) and shows warning UI with instructions to enable in Health app

### Diagnostics

- `DiagnosticsLogger.swift` — iPhone-side, persistent to `Documents/justzone2_diagnostics.txt`, NSLock thread-safe, callable via `dlog()` from any isolation context
- `WatchLogStore.swift` — Watch-side in-memory store, NSLock thread-safe, held as `nonisolated(unsafe) let` on `WatchSessionManager` so `nonisolated func wlog()` can append
- Watch flushes log to iPhone via `transferUserInfo(["type": "watchLog", ...])` at workout end
- Settings → Diagnostics card: entry count, Share Log (UIActivityViewController), Clear

### Strava TCX Enrichment

- **Cadence**: parsed from FTMS Indoor Bike Data bit 2 (uint16 / 2 = rpm)
- **Virtual speed**: Newton-Raphson solution to power equation, CdA=0.5 (hoods), ~17 mph at 168W
- **Distance**: integrated from virtual speed each timer tick
- **Calories**: `sum(watts) * interval / 1000` → kJ ≈ kcal
- TCX includes per-trackpoint `<DistanceMeters>`, `<Cadence>`, TPX `<Speed>` extension

### Key Files
- `HealthKitManager.swift` - HKWorkoutSession for background execution; `startWatchDisplayApp()` for Mode B
- `WatchSessionManager.swift` - Full Watch workout logic; `mirroringEstablished` flag; `wlog()`; HR permission detection
- `WatchConnectivityService.swift` - iPhone-side WCSession handling; `fallbackHeartRate` for WCSession HR fallback
- `WatchLogStore.swift` - Thread-safe Watch log store (Watch target)
- `DiagnosticsLogger.swift` - Persistent iPhone diagnostics logger
- `LiveActivityManager.swift` - ActivityKit Live Activity management
- `HistoryView.swift` - Graph with `MagnifyGesture` for pinch-to-zoom
- `StravaService.swift` - OAuth via Cloudflare Worker
- `ActivityDetailView.swift` - Individual activity detail with StreamChartView
- `StreamsCacheService.swift` - Caches Strava activity streams locally

### ActivityDetailView Architecture

The activity detail view (`ActivityDetailView.swift`) shows individual workout charts:

- **StreamChartView** - Displays HR and power data with Zone 2 band
- **ChartData struct** - Pre-computes all chart data once in init for performance (avoid repeated computed property calls during SwiftUI rendering)
- **Navigation** - Prev/next arrows below chart to navigate between activities without returning to list
- **Data trimming** - Attempts to trim warmup (before HR enters Zone 2) and cooldown (when power drops)

### Known Issues

**Activity chart end-trimming not working properly:**
The `ChartData` init in `ActivityDetailView.swift` tries to detect cooldown by finding where power drops below 60% of average. Current approach searches forward from 70% mark looking for a 10-point window where average drops below threshold. However, this still results in steep vertical dropoffs at the end of power data, causing the Y-axis to be too stretched.

Possible fixes to try:
- Use smoothed power data for detection instead of raw
- Try a more aggressive threshold (70-80% instead of 60%)
- Detect rate of change (derivative) rather than absolute threshold
- Simply trim a fixed percentage (e.g., last 5%) from the end
