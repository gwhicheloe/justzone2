import CoreBluetooth

enum Constants {
    // MARK: - Bluetooth UUIDs

    // Fitness Machine Service (FTMS) - for KICKR
    static let ftmsService = CBUUID(string: "1826")
    static let ftmsControlPoint = CBUUID(string: "2AD9")
    static let ftmsIndoorBikeData = CBUUID(string: "2AD2")
    static let ftmsFeature = CBUUID(string: "2ACC")
    static let ftmsStatus = CBUUID(string: "2ADA")

    // Heart Rate Service
    static let heartRateService = CBUUID(string: "180D")
    static let heartRateMeasurement = CBUUID(string: "2A37")

    // MARK: - FTMS Control Point OpCodes
    enum FTMSOpCode: UInt8 {
        case requestControl = 0x00
        case reset = 0x01
        case setTargetPower = 0x05
        case startOrResume = 0x07
        case stopOrPause = 0x08
    }

    // MARK: - Strava API
    // Client ID is public (used in OAuth URL shown to user)
    // Client secret is handled by the Cloudflare Worker - never in the app
    static let stravaClientId = "197806"
    static let stravaRedirectUri = "justzone2://justzone2"
    static let stravaAuthUrl = "https://www.strava.com/oauth/authorize"
    static let stravaUploadUrl = "https://www.strava.com/api/v3/uploads"

    // Cloudflare Worker handles token exchange securely
    // Deploy worker from /cloudflare-worker and update this URL
    static let stravaAuthWorkerURL = "https://justzone2-strava-auth.george-whicheloe.workers.dev"

    // MARK: - Workout Defaults
    static let defaultTargetPower = 150
    static let defaultDuration: TimeInterval = 30 * 60 // 30 minutes
    static let sampleInterval: TimeInterval = 1.0 // 1 Hz sampling

    // MARK: - Strava Branding
    // Official Strava brand color per https://developers.strava.com/guidelines/
    static let stravaOrangeHex = "#FC5200"

    // MARK: - Keychain Keys
    static let stravaAccessTokenKey = "strava_access_token"
    static let stravaRefreshTokenKey = "strava_refresh_token"
    static let stravaTokenExpiryKey = "strava_token_expiry"
}
