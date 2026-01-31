import AuthenticationServices
import Foundation

struct StravaActivity: Identifiable, Codable {
    let id: Int
    let name: String
    let type: String
    let startDate: Date
    let movingTime: Int // seconds
    let distance: Double // meters
    let averageWatts: Double?
    let averageHeartrate: Double?
    let maxHeartrate: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case startDate = "start_date"
        case movingTime = "moving_time"
        case distance
        case averageWatts = "average_watts"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
    }
}

@MainActor
class StravaService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadError: String?
    @Published var lastUploadedActivityId: Int?

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?

    override init() {
        super.init()
        loadTokensFromKeychain()
    }

    // MARK: - Authentication

    func authenticate() async throws {
        let authUrl = buildAuthURL()

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: "justzone2"
            ) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: StravaError.authenticationFailed)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: StravaError.authenticationFailed)
            }
        }

        // Extract authorization code from callback URL
        guard let code = extractAuthCode(from: callbackURL) else {
            throw StravaError.invalidAuthCode
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code)
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        clearKeychainTokens()
    }

    // MARK: - Fetch Activities

    func fetchActivityStreams(activityId: Int) async throws -> ActivityStreams {
        guard isAuthenticated else {
            throw StravaError.notAuthenticated
        }

        // Refresh token if expired
        if let expiry = tokenExpiry, Date() >= expiry {
            try await refreshAccessToken()
        }

        guard let token = accessToken else {
            throw StravaError.notAuthenticated
        }

        var components = URLComponents(string: "https://www.strava.com/api/v3/activities/\(activityId)/streams")!
        components.queryItems = [
            URLQueryItem(name: "keys", value: "heartrate,watts,time"),
            URLQueryItem(name: "key_by_type", value: "true")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaError.uploadFailed("Invalid response")
        }

        if httpResponse.statusCode == 404 {
            // Streams not available (e.g., manual activity)
            throw StravaError.streamsNotAvailable
        }

        if httpResponse.statusCode == 200 {
            let streamResponse = try JSONDecoder().decode(StreamsResponse.self, from: data)
            return ActivityStreams(
                activityId: activityId,
                fetchedAt: Date(),
                time: streamResponse.time?.data ?? [],
                heartrate: streamResponse.heartrate?.data,
                watts: streamResponse.watts?.data
            )
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StravaError.uploadFailed(errorMessage)
        }
    }

    func fetchActivities(page: Int = 1, perPage: Int = 100) async throws -> [StravaActivity] {
        guard isAuthenticated else {
            throw StravaError.notAuthenticated
        }

        // Refresh token if expired
        if let expiry = tokenExpiry, Date() >= expiry {
            try await refreshAccessToken()
        }

        guard let token = accessToken else {
            throw StravaError.notAuthenticated
        }

        var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaError.uploadFailed("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([StravaActivity].self, from: data)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StravaError.uploadFailed(errorMessage)
        }
    }

    // MARK: - Upload

    func uploadWorkout(_ workout: Workout) async throws -> Int {
        guard isAuthenticated else {
            throw StravaError.notAuthenticated
        }

        // Refresh token if expired
        if let expiry = tokenExpiry, Date() >= expiry {
            try await refreshAccessToken()
        }

        guard let token = accessToken else {
            throw StravaError.notAuthenticated
        }

        isUploading = true
        uploadProgress = 0
        uploadError = nil

        defer {
            isUploading = false
        }

        // Generate TCX file (simpler than FIT for our needs)
        let tcxData = TCXEncoder.encode(workout: workout)

        // Create upload request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: Constants.stravaUploadUrl)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Activity type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"activity_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("virtualride\r\n".data(using: .utf8)!)

        // Data type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("tcx\r\n".data(using: .utf8)!)

        // Name
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("Zone 2 Workout\r\n".data(using: .utf8)!)

        // File
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"workout.tcx\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/xml\r\n\r\n".data(using: .utf8)!)
        body.append(tcxData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        uploadProgress = 0.3

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaError.uploadFailed("Invalid response")
        }

        uploadProgress = 0.6

        if httpResponse.statusCode == 201 {
            // Upload initiated, now poll for completion
            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
            let activityId = try await pollUploadStatus(uploadId: uploadResponse.id, token: token)
            lastUploadedActivityId = activityId
            uploadProgress = 1.0
            return activityId
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StravaError.uploadFailed(errorMessage)
        }
    }

    // MARK: - Private Helpers

    private func buildAuthURL() -> URL {
        var components = URLComponents(string: Constants.stravaAuthUrl)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.stravaClientId),
            URLQueryItem(name: "redirect_uri", value: Constants.stravaRedirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "activity:read_all,activity:write"),
            URLQueryItem(name: "approval_prompt", value: "auto")
        ]
        return components.url!
    }

    private func extractAuthCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        // Use Cloudflare Worker to exchange code - client secret never touches the app
        var request = URLRequest(url: URL(string: "\(Constants.stravaAuthWorkerURL)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaError.tokenExchangeFailed
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Token exchange failed: \(errorMessage)")
            throw StravaError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        refreshToken = tokenResponse.refreshToken
        tokenExpiry = Date(timeIntervalSince1970: TimeInterval(tokenResponse.expiresAt))
        isAuthenticated = true

        saveTokensToKeychain()
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw StravaError.notAuthenticated
        }

        // Use Cloudflare Worker to refresh - client secret never touches the app
        var request = URLRequest(url: URL(string: "\(Constants.stravaAuthWorkerURL)/refresh")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StravaError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        tokenExpiry = Date(timeIntervalSince1970: TimeInterval(tokenResponse.expiresAt))

        saveTokensToKeychain()
    }

    private func pollUploadStatus(uploadId: Int, token: String) async throws -> Int {
        let statusUrl = URL(string: "\(Constants.stravaUploadUrl)/\(uploadId)")!

        for attempt in 0..<30 {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            var request = URLRequest(url: statusUrl)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let status = try JSONDecoder().decode(UploadStatusResponse.self, from: data)

            uploadProgress = 0.6 + Double(attempt) / 30.0 * 0.4

            if let activityId = status.activityId {
                return activityId
            }

            if let error = status.error {
                throw StravaError.uploadFailed(error)
            }

            if status.status == "Your activity is ready." {
                if let activityId = status.activityId {
                    return activityId
                }
            }
        }

        throw StravaError.uploadTimeout
    }

    // MARK: - Keychain

    private func saveTokensToKeychain() {
        if let accessToken = accessToken {
            KeychainHelper.save(key: Constants.stravaAccessTokenKey, value: accessToken)
        }
        if let refreshToken = refreshToken {
            KeychainHelper.save(key: Constants.stravaRefreshTokenKey, value: refreshToken)
        }
        if let tokenExpiry = tokenExpiry {
            KeychainHelper.save(key: Constants.stravaTokenExpiryKey, value: String(tokenExpiry.timeIntervalSince1970))
        }
    }

    private func loadTokensFromKeychain() {
        accessToken = KeychainHelper.load(key: Constants.stravaAccessTokenKey)
        refreshToken = KeychainHelper.load(key: Constants.stravaRefreshTokenKey)

        if let expiryString = KeychainHelper.load(key: Constants.stravaTokenExpiryKey),
           let expiryInterval = Double(expiryString) {
            tokenExpiry = Date(timeIntervalSince1970: expiryInterval)
        }

        isAuthenticated = accessToken != nil && refreshToken != nil
    }

    private func clearKeychainTokens() {
        KeychainHelper.delete(key: Constants.stravaAccessTokenKey)
        KeychainHelper.delete(key: Constants.stravaRefreshTokenKey)
        KeychainHelper.delete(key: Constants.stravaTokenExpiryKey)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first!
        return windowScene.windows.first ?? UIWindow(windowScene: windowScene)
    }
}

// MARK: - Response Models

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

private struct UploadResponse: Decodable {
    let id: Int
}

private struct UploadStatusResponse: Decodable {
    let activityId: Int?
    let status: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case status
        case error
    }
}

private struct StreamsResponse: Decodable {
    let time: StreamData?
    let heartrate: StreamData?
    let watts: StreamData?
}

private struct StreamData: Decodable {
    let data: [Int]
}

// MARK: - Errors

enum StravaError: LocalizedError {
    case authenticationFailed
    case invalidAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notAuthenticated
    case uploadFailed(String)
    case uploadTimeout
    case streamsNotAvailable

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidAuthCode:
            return "Invalid authorization code"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .notAuthenticated:
            return "Not authenticated with Strava"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .uploadTimeout:
            return "Upload timed out"
        case .streamsNotAvailable:
            return "Stream data not available for this activity"
        }
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
