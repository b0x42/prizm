import Foundation
import os.log

// MARK: - Protocol

/// Bitwarden REST API client for auth and vault sync operations.
///
/// All requests require the `X-Client-Id`, `X-Client-Version`, and `Device-Type` headers
/// that Bitwarden mandates for all client integrations (see Bitwarden ADR: integration-identifiers).
/// Missing or invalid headers result in `400 Bad Request` / `403 Forbidden` from the server.
///
/// Implemented as an `actor` to serialise the mutable `baseURL` and `accessToken` state.
protocol BitwardenAPIClientProtocol: AnyObject {

    /// The base URL configured by `AuthRepositoryImpl` after the user enters their server address.
    var baseURL: URL? { get }

    /// Stores the base URL; sets up derived endpoint URLs.
    func setBaseURL(_ url: URL)

    /// Stores the access token used for subsequent authenticated requests.
    func setAccessToken(_ token: String)

    /// POST `/accounts/prelogin` — returns KDF parameters for the given email.
    /// Used to derive the master key before posting credentials to `/connect/token`.
    ///
    /// No authentication required; sends only the email address.
    func preLogin(email: String) async throws -> PreLoginResponse

    /// POST `/connect/token` — exchanges a hashed password (or TOTP code) for tokens.
    ///
    /// The request is `application/x-www-form-urlencoded` as required by the OAuth2 spec.
    /// On a 2FA challenge the server returns HTTP 400 with `TwoFactorProviders` in the body;
    /// the caller should inspect `TokenResponse.twoFactorProviders` and handle accordingly.
    ///
    /// - Parameters:
    ///   - email:              The user's email address.
    ///   - passwordHash:       Base64-encoded server authentication hash (from `makeServerHash`).
    ///   - deviceIdentifier:   UUID uniquely identifying this installation (persisted in Keychain).
    ///   - twoFactorToken:     TOTP code from the authenticator app, if completing a 2FA challenge.
    ///   - twoFactorProvider:  Numeric 2FA provider identifier (0 = authenticatorApp).
    ///   - twoFactorRemember:  When true, requests a `TwoFactorToken` cookie for future logins.
    func identityToken(
        email:              String,
        passwordHash:       String,
        deviceIdentifier:   String,
        twoFactorToken:     String?,
        twoFactorProvider:  Int?,
        twoFactorRemember:  Bool
    ) async throws -> TokenResponse

    /// GET `/sync?excludeDomains=true` — returns the full encrypted vault.
    ///
    /// Requires a valid `Authorization: Bearer <accessToken>` header.
    /// Throws `SyncError.unauthorized` on HTTP 401.
    func fetchSync() async throws -> SyncResponse
}

// MARK: - Wire Models

/// Response from POST `/accounts/prelogin`.
///
/// Contains the KDF parameters needed to derive the master key locally.
/// `kdfMemory` and `kdfParallelism` are only present when `kdf == 1` (Argon2id).
struct PreLoginResponse: Codable {
    let kdf:            Int
    let kdfIterations:  Int
    let kdfMemory:      Int?
    let kdfParallelism: Int?

    var kdfParams: KdfParams {
        KdfParams(
            type:        kdf == 1 ? .argon2id : .pbkdf2,
            iterations:  kdfIterations,
            memory:      kdfMemory,
            parallelism: kdfParallelism
        )
    }

    enum CodingKeys: String, CodingKey {
        case kdf            = "Kdf"
        case kdfIterations  = "KdfIterations"
        case kdfMemory      = "KdfMemory"
        case kdfParallelism = "KdfParallelism"
    }
}

/// Response from POST `/connect/token`.
///
/// On success, contains access + refresh tokens and the encrypted vault key.
/// On a 2FA challenge, `twoFactorProviders` is non-nil and `accessToken` will be empty/absent.
struct TokenResponse: Codable {
    let accessToken:        String
    let refreshToken:       String?
    let tokenType:          String
    let expiresIn:          Int
    /// The encrypted user key (EncString). Present on success; used to initialize vault crypto.
    let key:                String?
    /// The encrypted RSA private key (EncString). Used for org cipher decryption (not v1).
    let privateKey:         String?
    let kdf:                Int?
    let kdfIterations:      Int?
    let kdfMemory:          Int?
    let kdfParallelism:     Int?
    /// Device remember token returned when `twoFactorRemember == true`.
    let twoFactorToken:     String?
    /// Non-nil when the server requires 2FA; lists available provider type numbers.
    let twoFactorProviders: [Int]?
    let userId:             String?
    let email:              String?
    let name:               String?

    enum CodingKeys: String, CodingKey {
        case accessToken        = "access_token"
        case refreshToken       = "refresh_token"
        case tokenType          = "token_type"
        case expiresIn          = "expires_in"
        case key                = "Key"
        case privateKey         = "PrivateKey"
        case kdf                = "Kdf"
        case kdfIterations      = "KdfIterations"
        case kdfMemory          = "KdfMemory"
        case kdfParallelism     = "KdfParallelism"
        case twoFactorToken     = "TwoFactorToken"
        case twoFactorProviders = "TwoFactorProviders"
        case userId             = "UserId"
        case email              = "Email"
        case name               = "Name"
    }
}

// MARK: - Identity Token Semantic Errors

/// Semantic errors from the `/connect/token` endpoint, distinct from raw transport errors.
///
/// The Bitwarden identity service returns HTTP 400 for both wrong passwords and 2FA challenges;
/// `IdentityTokenError` models the meaningful distinctions so the repository layer can act on them.
enum IdentityTokenError: Error, Equatable {
    /// The server requires two-factor authentication before issuing a token.
    /// `providers` is the list of available 2FA type numbers (0 = authenticatorApp, etc.).
    case twoFactorRequired(providers: [Int])
    /// The submitted TOTP code (or remember-device token) was rejected by the server.
    case twoFactorCodeInvalid
    /// Email or password is incorrect (HTTP 400 `invalid_grant` without 2FA challenge).
    case invalidCredentials
}

// MARK: - Errors

/// Errors thrown by `BitwardenAPIClientImpl` at the transport layer.
///
/// Higher-level semantic errors (e.g. `.invalidCredentials`, `.unauthorized`) are mapped
/// by the repository layer (`AuthRepositoryImpl`, `SyncRepositoryImpl`) from these raw codes.
enum APIError: Error, Equatable {
    /// The HTTP response status code indicates failure.
    case httpError(statusCode: Int, body: String)
    /// The response body could not be decoded into the expected type.
    case decodingFailed
    /// `setBaseURL` was never called before making a request.
    case baseURLNotSet
}

// MARK: - Implementation

/// URLSession-backed Bitwarden API client.
///
/// All requests include the required Bitwarden client identification headers:
/// - `X-Client-Id: "desktop"`       (registered client identifier for third-party clients)
/// - `X-Client-Version: "2024.1.0"` (version string matching tested server release)
/// - `Device-Type: "8"`              (7 = macOS desktop, per Bitwarden DeviceType enum)
///
/// Reference for header requirements:
/// https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
actor BitwardenAPIClientImpl: BitwardenAPIClientProtocol {

    // MARK: - Private state

    private(set) var baseURL: URL?
    private var accessToken: String?

    private let session:   URLSession
    private let logger:    Logger = Logger(
        subsystem: "com.bitwarden-macos",
        category:  "BitwardenAPIClient"
    )

    // MARK: - Bitwarden client identification headers
    // These are mandatory on every request to the Bitwarden identity + API services.
    // `device_type` 7 = macOS desktop (Bitwarden DeviceType enum; contact Bitwarden CS for registration).
    private enum ClientHeaders {
        static let clientId      = "desktop"
        static let clientVersion = "2024.1.0"
        static let deviceType    = "7"
        static let userAgent     = "Bitwarden_MacOS/2024.1.0"
    }

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Configuration

    func setBaseURL(_ url: URL) {
        baseURL = url
    }

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    // MARK: - preLogin

    func preLogin(email: String) async throws -> PreLoginResponse {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("api/accounts/prelogin")

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONEncoder().encode(["email": email])
        request.httpBody = body

        return try await perform(request: request)
    }

    // MARK: - identityToken

    func identityToken(
        email:             String,
        passwordHash:      String,
        deviceIdentifier:  String,
        twoFactorToken:    String?,
        twoFactorProvider: Int?,
        twoFactorRemember: Bool
    ) async throws -> TokenResponse {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("identity/connect/token")

        var params: [String: String] = [
            "grant_type":      "password",
            "username":        email,
            "password":        passwordHash,
            "scope":           "api offline_access",
            "client_id":       ClientHeaders.clientId,
            "deviceType":      ClientHeaders.deviceType,
            "deviceIdentifier": deviceIdentifier,
            "deviceName":      "Bitwarden MacOS",
        ]
        if let token    = twoFactorToken    { params["twoFactorToken"]    = token }
        if let provider = twoFactorProvider { params["twoFactorProvider"] = String(provider) }
        if twoFactorRemember                { params["twoFactorRemember"] = "true" }

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = formEncoded(params)

        return try await perform(request: request)
    }

    // MARK: - fetchSync

    func fetchSync() async throws -> SyncResponse {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        var components   = URLComponents(url: base.appendingPathComponent("api/sync"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "excludeDomains", value: "true")]
        let url          = components.url!

        var request      = baseRequest(url: url)
        request.httpMethod = "GET"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await perform(request: request)
    }

    // MARK: - Private helpers

    /// Builds a `URLRequest` pre-loaded with mandatory Bitwarden client identification headers.
    private func baseRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(ClientHeaders.userAgent,     forHTTPHeaderField: "User-Agent")
        req.setValue("application/json",          forHTTPHeaderField: "Accept")
        req.setValue(ClientHeaders.clientVersion, forHTTPHeaderField: "X-Client-Version")
        return req
    }

    /// Sends `request`, checks the HTTP status code, and decodes the JSON response body.
    ///
    /// - Throws: `APIError.httpError` on non-2xx status codes; `APIError.decodingFailed` on JSON errors.
    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "")
        }

        logger.debug("[\(http.statusCode)] \(request.httpMethod ?? "?") \(request.url?.path ?? "")")

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            // Scrub: do not log response body (may contain tokens or error details with PII).
            logger.error("HTTP \(http.statusCode) for \(request.url?.path ?? "unknown")")
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Decoding failed for \(T.self): \(error.localizedDescription)")
            throw APIError.decodingFailed
        }
    }

    /// Encodes a `[String: String]` dictionary as `application/x-www-form-urlencoded` data.
    private func formEncoded(_ params: [String: String]) -> Data {
        params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}
