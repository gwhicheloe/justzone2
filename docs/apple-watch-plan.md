# Apple Watch Support - Planning Document

## User Scenarios

### Primary: Bluetooth HR Strap (Most Users)
- Chest strap remains the default/recommended HR source
- More accurate than optical HR, especially at higher intensities
- Current implementation works well

### Secondary: Apple Watch as HR Source
- Alternative for users without a chest strap
- Watch optical sensor is "good enough" for Zone 2 (lower intensity)
- Requires Watch companion app to sample and send HR

### Companion Display: Watch Video on Phone, Glance at Watch
- User watches Netflix/YouTube on phone during indoor training
- Glances at wrist to check: current HR, current power, time remaining
- No need to switch apps or interrupt video
- This is the key value proposition for the Watch app

## Features Required

### 1. Apple Watch as HR Source (Optional)
- In SetupView, offer "Apple Watch" as alternative to Bluetooth HR monitors
- Watch samples HR and sends to iPhone via WatchConnectivity
- Falls back gracefully if Watch disconnects

### 2. Watch Companion Display
- Simple watch face showing:
  - Current HR (large)
  - Current Power (large)
  - Chunk timer countdown
  - "Chunk 2 of 3" indicator
- Minimal controls (maybe just pause/stop)
- iPhone remains the "brain" - controls KICKR, saves to HealthKit/Strava

---

## Architecture Overview

### Current Data Flow
```
[Bluetooth HR Strap] → HeartRateService → WorkoutViewModel → UI
[KICKR Trainer]      → KickrService    → WorkoutViewModel → UI
```

### With Watch HR Source
```
[Apple Watch HR] → WCSession → HeartRateService → WorkoutViewModel → UI
[KICKR Trainer]  → KickrService                 → WorkoutViewModel → UI
```

### With Full Watch App
```
┌─────────────────┐         ┌─────────────────┐
│   iPhone App    │ ←─────→ │   Watch App     │
│                 │ WCSession│                 │
│ • KICKR control │         │ • HR sampling   │
│ • Workout logic │ ←── HR  │ • Display UI    │
│ • Strava upload │ ──→ Power/Time           │
│ • HealthKit save│         │                 │
└─────────────────┘         └─────────────────┘
```

---

## Implementation Phases

### Phase 1: Full Watch Support (Both Features)
**Data flow: Bidirectional**
- iPhone → Watch: Workout metrics (power, time, state)
- Watch → iPhone: Heart rate (if Watch selected as HR source)

#### Watch as HR Source
The app already handles "no HR" gracefully - shows "--" and continues. Watch HR is no different:
- Watch HR available → display HR
- Watch HR disconnects → show "-- BPM", workout continues
- Same behavior as Bluetooth HR strap disconnecting

#### Implementation Steps
1. Create watchOS target with WatchConnectivity
2. Watch: Sample HR via HealthKit, send to iPhone
3. Watch: Display workout metrics received from iPhone
4. iPhone: Add WatchConnectivityService for bidirectional sync
5. SetupView: Add "Apple Watch" option in HR device list

**Files to create:**
- `JustZone2Watch/JustZone2WatchApp.swift` - Watch app entry point
- `JustZone2Watch/WorkoutView.swift` - Shows HR, Power, Chunk timer
- `JustZone2Watch/WatchSessionManager.swift` - WCSession handling + HR sampling
- `justzone2/Services/WatchConnectivityService.swift` - iPhone-side WCSession

**Files to modify:**
- `justzone2/ViewModels/WorkoutViewModel.swift` - Push updates to Watch, receive HR from Watch
- `justzone2/Views/SetupView.swift` - Add "Apple Watch" to HR device picker
- `justzone2/ViewModels/SetupViewModel.swift` - Track Watch HR selection

**Risk: Low** - HR source is already optional; Watch HR treated same as Bluetooth HR

---

## Key Technical Decisions

### How Watch HR Differs from Bluetooth HR

| | Bluetooth HR Strap | Apple Watch |
|---|---|---|
| Discovery | Bluetooth scan | Already paired to iPhone |
| Protocol | CoreBluetooth (UUID 180D) | WatchConnectivity (WCSession) |
| In SetupView | Appears in device list | Separate "Apple Watch" option |
| Connection | Manual connect button | Automatic via WCSession |

**Key difference:** The Watch app must be running to send HR. When user starts workout on iPhone with Watch HR selected:
1. iPhone sends "workout starting" to Watch via WCSession
2. Watch app activates and starts sampling HR from its HealthKit
3. Watch sends HR to iPhone every ~1 second
4. If Watch app closes or disconnects → iPhone shows "-- BPM"

### WatchConnectivity Message Types

```swift
// iPhone → Watch
["type": "workoutUpdate",
 "heartRate": 142,
 "power": 150,
 "elapsedTime": 1234,
 "chunkRemaining": 456,
 "currentChunk": 2,
 "totalChunks": 3,
 "state": "running"]

["type": "workoutEnded"]

// Phase 2: Watch → iPhone (adds complexity)
["type": "heartRate", "bpm": 142, "timestamp": 1234567890.0]
```

### Watch App HealthKit Permissions
- Watch app needs separate HealthKit authorization
- Can read HR directly from Watch's HealthKit store
- Use `HKWorkoutSession` on Watch for continuous HR access

---

## Complexity Assessment

| Feature | Effort | Risk | Value |
|---------|--------|------|-------|
| Watch as HR source | Medium | Low | High |
| Watch companion app | High | Medium | Medium |

**Recommendation:** Start with Phase 1 (HR source only). It delivers the core value (no chest strap needed) with manageable complexity. Phase 2 can come later if there's demand.

---

## Watch App UI Mockup

```
┌─────────────────────┐
│   Chunk 2 of 3      │  (small, secondary)
│                     │
│   ❤️ 132            │  (large, red)
│      BPM            │
│                     │
│   ⚡ 148            │  (large, blue)
│      W              │
│                     │
│     07:24           │  (medium, green)
│   remaining         │
│                     │
│  ⏸️  ⏹️             │  (pause/stop buttons)
└─────────────────────┘
```

## CRITICAL: Stability First

**A dropped workout would spell the end of the app.** The Watch integration must NEVER threaten the core workout stability.

### Architecture Principles

1. **iPhone is the source of truth** - All workout logic stays on iPhone
2. **Watch is optional** - Workout runs perfectly fine without Watch
3. **Graceful degradation** - Watch disconnect = no problem, workout continues
4. **Fire and forget** - iPhone sends updates to Watch, doesn't wait for acknowledgment
5. **No Watch → iPhone control** - Watch can't pause/stop/affect iPhone workout (initially)
6. **Separate from core loop** - WatchConnectivity code isolated, can't crash workout timer

### What Happens If Watch Disconnects?
- **iPhone**: Continues workout normally, no impact whatsoever
- **Watch**: Shows "Reconnecting..." or goes back to app launcher
- **HR (if Watch was source)**: Falls back to "-- BPM" display, workout continues without HR

### Implementation Guard Rails
```swift
// All Watch communication wrapped in try/catch, failures logged but ignored
func sendUpdateToWatch(_ data: WorkoutUpdate) {
    guard WCSession.default.isReachable else { return } // Silent fail
    do {
        try WCSession.default.sendMessage(data.dictionary, replyHandler: nil, errorHandler: { _ in })
    } catch {
        // Log but don't crash - Watch is optional
    }
}
```

### Testing Requirements
- [ ] Start workout, disable Watch Bluetooth mid-workout → workout continues
- [ ] Start workout without Watch paired → no crashes, no errors shown
- [ ] Watch app crashes → iPhone workout unaffected
- [ ] Poor connection (watch in another room) → iPhone workout stable

## Recommendation

**Implement both features together:**
1. Watch as HR source (optional, user selects in Setup)
2. Watch companion display (shows metrics while watching video on phone)

**Why this is safe:**
- HR source is already optional in the app
- Bluetooth HR disconnecting = workout continues with "-- BPM"
- Watch HR disconnecting = same behavior, workout continues
- Watch display is purely passive, receives updates from iPhone

**Estimated scope:** ~600-800 lines of new code across Watch target + iPhone services
