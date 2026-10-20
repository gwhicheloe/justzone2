# Strava API review: answers for the capacity-increase form

Prepared 20 October 2026. Submit only once the dashboard shows **10 of 10 athletes connected**: Strava denies requests from apps below the Standard-tier limit.

Form: https://share.hsforms.com/1VXSwPUYqSH6IxK0y51FjHwcnkd8

## Before you submit

1. Upgrade to 10 athletes from the API Settings dashboard (https://www.strava.com/settings/api → My API Application). Requires an active Strava subscription on your account.
2. Wait until 10 athletes are connected.
3. **Update the privacy policy** (see the draft at the end). The current policy only describes uploading to Strava; it doesn't say the app reads your Strava activities or caches them on the device. A reviewer comparing the policy with the requested scopes would notice.
4. Ideally have **1.0.5 live** first. Two answers below (clearing cached Strava data on disconnect, clear error messages at the athlete limit) are true from 1.0.5. If 1.0.5 isn't live yet, say "in the next release" instead.

## Screenshots to attach

On your Desktop (not in git, as the first one shows your email address):
- `Strava-2-OAuth-consent.png`: Strava's own authorize page for client 197806. The strongest evidence.
- `Strava-1-API-registration.png`: the API application page. The client secret is masked; never click "Show" before taking a screenshot.

In the repo:
- `docs/app-store-screenshots/1.0.2/iphone-5-summary.png`: the end-of-ride summary after an upload.
- `docs/app-store-screenshots/1.0.2/iphone-2-setup.png`: Setup, with the Strava connection tile.

## Answers

**App name:** JustZone2

**Client ID:** 197806

**Current tier and capacity:** Standard tier, 10 connected athletes (at the limit).

**Capacity requested:** 1,000 athletes. *(Your call. Standard tier allows up to 9,999 after review; 1,000 gives plenty of room without looking speculative.)*

**What the app does:**
JustZone2 is a paid iOS app (iPhone, iPad and Apple Watch, one-time purchase, no subscription, no ads) for indoor cycling on a smart trainer. It controls the trainer's resistance in ERG mode to keep the rider's heart rate in a chosen training zone, typically Zone 2, and records heart rate, power and cadence. It also has an optional interval builder for structured sessions.

**Links:**
- App Store: https://apps.apple.com/app/id6758547732
- Website: https://www.justzone2.com
- Privacy policy: https://www.justzone2.com/privacy
- Source: https://github.com/gwhicheloe/justzone2

**How the app uses the Strava API:**
1. *Upload (activity:write).* When a ride finishes, the rider can tap to upload it to their own Strava account. The upload is a TCX file of that ride (heart rate, power, cadence, virtual speed and distance), as a Virtual Ride, with a short description of the session. Nothing is uploaded without the rider choosing to.
2. *Read (activity:read_all).* The History tab shows the rider's own Zone 2 rides over time, plotting power against heart rate to show aerobic fitness improving. It reads the rider's activity list and, when they open a ride, that ride's heart rate, power and time streams.

**Why activity:read_all rather than activity:read:**
Many riders keep indoor trainer sessions private ("Only you"), and those are exactly the rides the History charts are built from. With activity:read, a rider's own private training would be missing from their own charts. The data is only ever shown to the same rider, on their own device.

**Where Strava data goes, and how long it's kept:**
- Strava data is stored only on the rider's device: the activity list and opened streams are cached so History loads quickly and works offline. JustZone2 has no server that stores, processes or analyses Strava data.
- Disconnecting Strava in the app removes the tokens and the cached Strava activities and streams from the device. Riders can also clear all data from Settings.
- Strava data isn't shared with anyone, sold, used for advertising, used for analytics, or used to train any AI or machine-learning model.

**Authentication and security:**
- OAuth runs in Apple's ASWebAuthenticationSession, with an ephemeral browser session so the rider always sees Strava's own sign-in and consent screens.
- The client secret is never in the app or its source code. The authorization code is exchanged for tokens by a small Cloudflare Worker that holds the secret. The Worker only forwards the token request to Strava and returns the response; it doesn't store or log tokens, and no activity data ever passes through it.
- Access and refresh tokens are stored in the iOS Keychain on the rider's device.

**Brand guidelines:**
- The app uses Strava's official, unmodified "Connect with Strava" button.
- It describes itself as "Compatible with Strava" and states that it isn't affiliated with or endorsed by Strava.
- The Strava logo isn't used anywhere else, and the app's name and branding don't include Strava.

**Expected API usage:**
Light. Per rider per day: typically one activity-list request when History is opened (more only on first sync), one streams request per ride they open, and one upload with a few status checks after each ride. Well within the Standard-tier limits.

**Growth:**
The app launched on the App Store on 23 September 2026 and reached the 10-athlete limit on [DATE]. *(Fill in when you submit.)*

## Draft privacy-policy addition

For the "Third-Party Services: Strava" part of `website/privacy.html`:

> **Strava (optional).** If you connect your Strava account, JustZone2 can:
> - upload rides you choose to your Strava account; and
> - read your Strava activities, including private ones, so the History tab can chart your Zone 2 rides over time.
>
> Activities read from Strava are stored only on your device, to make History fast and available offline. They're never sent to us or to anyone else. Disconnecting Strava in the app deletes your Strava sign-in and the Strava data stored on your device. You can also revoke JustZone2's access at any time in your Strava settings under My Apps.
