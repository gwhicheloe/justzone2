# JustZone2 Strava Auth Worker

Cloudflare Worker that securely handles Strava OAuth token exchange. The Strava client secret never touches the iOS app.

## Setup

### 1. Install Wrangler CLI

```bash
npm install -g wrangler
```

### 2. Login to Cloudflare

```bash
wrangler login
```

### 3. Add Secrets

```bash
cd cloudflare-worker
wrangler secret put STRAVA_CLIENT_ID
# Enter your Strava client ID when prompted

wrangler secret put STRAVA_CLIENT_SECRET
# Enter your Strava client secret when prompted
```

### 4. Deploy

```bash
npm run deploy
```

You'll get a URL like: `https://justzone2-strava-auth.<your-subdomain>.workers.dev`

### 5. Update iOS App

In `Constants.swift`, set:
```swift
static let stravaAuthWorkerURL = "https://justzone2-strava-auth.<your-subdomain>.workers.dev"
```

## Endpoints

### POST /token
Exchange authorization code for tokens.

```json
Request:  { "code": "authorization_code_from_strava" }
Response: { "access_token": "...", "refresh_token": "...", "expires_at": 1234567890 }
```

### POST /refresh
Refresh expired tokens.

```json
Request:  { "refresh_token": "..." }
Response: { "access_token": "...", "refresh_token": "...", "expires_at": 1234567890 }
```

## Local Development

```bash
npm run dev
```

This starts a local server at `http://localhost:8787` for testing.
