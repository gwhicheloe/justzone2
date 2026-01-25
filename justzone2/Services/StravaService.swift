import AuthenticationServices
import Foundation

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
            URLQueryItem(name: "scope", value: "activity:write"),
            URLQueryItem(name: "approval_prompt", value: "auto")
        ]
        return components.url!
    }

    private func extractAuthCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        var request = URLRequest(url: URL(string: Constants.stravaTokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": Constants.stravaClientId,
            "client_secret": Constants.stravaClientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": Constants.stravaRedirectUri
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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

        var request = URLRequest(url: URL(string: Constants.stravaTokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": Constants.stravaClientId,
            "client_secret": Constants.stravaClientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

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
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
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

// MARK: - Errors

enum StravaError: LocalizedError {
    case authenticationFailed
    case invalidAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notAuthenticated
    case uploadFailed(String)
    case uploadTimeout

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
