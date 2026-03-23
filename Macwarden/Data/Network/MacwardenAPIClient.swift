import Foundation
import os.log

// MARK: - Protocol

/// Bitwarden REST API client for auth and vault sync operations.
///
/// All requests require the `X-Client-Id`, `X-Client-Version`, and `Device-Type` headers
/// that Bitwarden mandates for all client integrations.
/// Reference: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
/// Missing or invalid headers result in `400 Bad Request` / `403 Forbidden` from the server.
///
/// Implemented as an `actor` to serialise the mutable `baseURL` and `accessToken` state.
protocol MacwardenAPIClientProtocol: Actor {

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

    /// POST `/identity/connect/token` with `grant_type=refresh_token` — exchanges a refresh token
    /// for a new access token. Updates the stored access token on success.
    ///
    /// - Returns: A tuple of (newAccessToken, newRefreshToken). The refresh token may be nil
    ///   if the server does not rotate it.
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, refreshToken: String?)

    /// PUT `/api/ciphers/{id}` — updates an existing cipher with re-encrypted field values.
    ///
    /// Requires a valid `Authorization: Bearer <accessToken>` header.
    /// The request body is a JSON-encoded `RawCipher` with all sensitive fields re-encrypted
    /// as EncStrings (type-2 AES-256-CBC + HMAC-SHA256).
    /// On success the server returns the updated cipher, which is decoded back into `RawCipher`.
    ///
    /// Reference: Bitwarden Server API PUT /api/ciphers/{id}
    func updateCipher(id: String, cipher: RawCipher) async throws -> RawCipher

    /// DELETE `/api/ciphers/{id}` — soft-deletes a cipher by moving it to Trash.
    ///
    /// Sets `deletedDate` on the server. The item remains in the user's vault data and
    /// can be restored. Bitwarden cloud auto-purges trashed items after 30 days server-side;
    /// self-hosted Vaultwarden only auto-purges if `TRASH_AUTO_DELETE_DAYS` is configured.
    ///
    /// Reference: Bitwarden Server API DELETE /api/ciphers/{id}
    func softDeleteCipher(id: String) async throws

    /// PUT `/api/ciphers/{id}/restore` — restores a trashed cipher to the active vault.
    ///
    /// Clears `deletedDate` on the server. The item becomes visible in the active vault again.
    ///
    /// Reference: Bitwarden Server API PUT /api/ciphers/{id}/restore
    func restoreCipher(id: String) async throws

    /// DELETE `/api/ciphers/purge` — permanently deletes all trashed ciphers.
    ///
    /// **Irreversible.** All items with a non-nil `deletedDate` are permanently removed
    /// from the server.
    ///
    /// Note: The Bitwarden server accepts an optional `masterPasswordHash` body parameter on
    /// this endpoint as an additional confirmation. v1 omits it and relies on the UI confirmation
    /// alert instead. A future phase should add master-password re-verification before purge.
    /// TODO: Add master-password re-prompt before calling this endpoint (deferred — requires
    /// SecureEnclave entitlement + re-hash flow).
    ///
    /// Reference: Bitwarden Server API DELETE /api/ciphers/purge
    func purgeTrashedCiphers() async throws
}

// MARK: - Wire Models

/// Response from POST `/accounts/prelogin`.
///
/// Contains the KDF parameters needed to derive the master key locally.
/// `kdfMemory` and `kdfParallelism` are only present when `kdf == 1` (Argon2id).
nonisolated struct PreLoginResponse: Codable {
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

    // Vaultwarden/Bitwarden returns camelCase keys matching the property names,
    // so no custom CodingKeys needed — synthesized conformance handles it.
}

/// Response from POST `/connect/token`.
///
/// On success, contains access + refresh tokens and the encrypted vault key.
/// On a 2FA challenge, `twoFactorProviders` is non-nil and `accessToken` will be empty/absent.
nonisolated struct TokenResponse: Codable {
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
nonisolated enum IdentityTokenError: Error, Equatable {
    /// The server requires two-factor authentication before issuing a token.
    /// `providers` is the list of available 2FA type numbers (0 = authenticatorApp, etc.).
    case twoFactorRequired(providers: [Int])
    /// The submitted TOTP code (or remember-device token) was rejected by the server.
    case twoFactorCodeInvalid
    /// Email or password is incorrect (HTTP 400 `invalid_grant` without 2FA challenge).
    case invalidCredentials
}

// MARK: - Errors

/// Errors thrown by `MacwardenAPIClientImpl` at the transport layer.
///
/// Higher-level semantic errors (e.g. `.invalidCredentials`, `.unauthorized`) are mapped
/// by the repository layer (`AuthRepositoryImpl`, `SyncRepositoryImpl`) from these raw codes.
nonisolated enum APIError: Error, Equatable {
    /// The HTTP response status code indicates failure.
    case httpError(statusCode: Int, body: String)
    /// The response body could not be decoded into the expected type.
    case decodingFailed
    /// `setBaseURL` was never called before making a request.
    case baseURLNotSet
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let body):
            return body.isEmpty ? "Server error \(statusCode)." : "Server error \(statusCode): \(body)"
        case .decodingFailed:
            return "The server response could not be read. Please try again."
        case .baseURLNotSet:
            return "No server URL is configured."
        }
    }
}

// MARK: - Implementation

/// URLSession-backed Bitwarden API client.
///
/// All requests include the required Bitwarden client identification headers:
/// - `X-Client-Id: "desktop"`       (registered client identifier for third-party clients)
/// - `X-Client-Version: "2024.1.0"` (version string matching tested server release)
/// - `Device-Type: "7"`             (7 = macOS desktop, per Bitwarden DeviceType enum)
///
/// Header requirements: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
/// DeviceType enum values: https://github.com/bitwarden/server/blob/main/src/Core/Enums/DeviceType.cs
actor MacwardenAPIClientImpl: MacwardenAPIClientProtocol {

    // MARK: - Private state

    private(set) var baseURL: URL?
    private var accessToken: String?

    private let session:   URLSession
    private let logger:    Logger = Logger(
        subsystem: "com.macwarden",
        category:  "MacwardenAPIClient"
    )

    // MARK: - Bitwarden client identification headers
    // These are mandatory on every request to the Bitwarden identity + API services.
    // deviceType 7 = macOS desktop per the Bitwarden DeviceType enum:
    // https://github.com/bitwarden/server/blob/main/src/Core/Enums/DeviceType.cs
    private enum ClientHeaders {
        static let clientId      = "desktop"
        static let clientVersion = "2024.1.0"
        static let deviceType    = "7"
        static let userAgent     = "Macwarden/2024.1.0"
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

        if DebugConfig.isEnabled {
            logger.debug("[debug] preLogin → POST \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONEncoder().encode(["email": email])
        request.httpBody = body

        let response: PreLoginResponse = try await perform(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] preLogin ← kdf=\(response.kdf, privacy: .public) iterations=\(response.kdfIterations, privacy: .public) memory=\(response.kdfMemory.map(String.init) ?? "nil", privacy: .public) parallelism=\(response.kdfParallelism.map(String.init) ?? "nil", privacy: .public)")
        }
        return response
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

        if DebugConfig.isEnabled {
            let isTOTP = twoFactorToken != nil
            logger.debug("[debug] identityToken → POST \(url.absoluteString, privacy: .public) 2FA=\(isTOTP, privacy: .public) provider=\(twoFactorProvider.map(String.init) ?? "nil", privacy: .public)")
        }

        var params: [String: String] = [
            "grant_type":      "password",
            "username":        email,
            "password":        passwordHash,
            "scope":           "api offline_access",
            "client_id":       ClientHeaders.clientId,
            "deviceType":      ClientHeaders.deviceType,
            "deviceIdentifier": deviceIdentifier,
            "deviceName":      "Macwarden",
        ]
        if let token    = twoFactorToken    { params["twoFactorToken"]    = token }
        if let provider = twoFactorProvider { params["twoFactorProvider"] = String(provider) }
        if twoFactorRemember                { params["twoFactorRemember"] = "true" }

        if DebugConfig.isEnabled {
            // Log all params except password (server hash) — scrubbed for security.
            let scrubbed = params.filter { $0.key != "password" }
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " | ")
            logger.debug("[debug] identityToken params (password scrubbed): \(scrubbed, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = formEncoded(params)

        return try await performIdentityToken(request: request)
    }

    /// Specialized perform for the identity token endpoint.
    ///
    /// The Bitwarden identity service overloads HTTP 400 for three distinct outcomes —
    /// disambiguation requires inspecting the response body:
    ///   1. 2FA challenge (occurs on first password attempt when 2FA is enabled):
    ///      body contains `"TwoFactorProviders2"` key → throw `.twoFactorRequired`
    ///   2. Bad TOTP code (occurs on the second request when the code is wrong):
    ///      `error_description` contains "Two-factor" → throw `.twoFactorCodeInvalid`
    ///   3. Wrong password (no 2FA in play, or bad credentials at any step):
    ///      generic `invalid_grant` body → throw `.invalidCredentials`
    /// Cases 2 and 3 use the same fallthrough path because they produce the same
    /// user-facing error: re-enter your password / code.
    private func performIdentityToken(request: URLRequest) async throws -> TokenResponse {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "")
        }

        logger.debug("[\(http.statusCode)] \(request.httpMethod ?? "?") \(request.url?.path ?? "")")

        if http.statusCode == 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            if DebugConfig.isEnabled {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let keys = json.keys.sorted().joined(separator: ", ")
                    logger.debug("[debug] identityToken 400 body keys: [\(keys, privacy: .public)]")
                    // error_description and message are server-generated error text, not secrets.
                    if let errorDesc = json["error_description"] as? String {
                        logger.debug("[debug] identityToken 400 error_description: \(errorDesc, privacy: .public)")
                    }
                    if let msg = json["message"] as? String {
                        logger.debug("[debug] identityToken 400 message: \(msg, privacy: .public)")
                    }
                    if let errorModel = json["errorModel"] as? [String: Any],
                       let errMsg = errorModel["message"] as? String {
                        logger.debug("[debug] identityToken 400 errorModel.message: \(errMsg, privacy: .public)")
                    }
                } else {
                    logger.debug("[debug] identityToken 400 body (non-JSON): \(body.prefix(200), privacy: .public)")
                }
            }
            // Parse the error body to determine the specific error type.
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 2FA challenge: server returns TwoFactorProviders2 dict with available providers.
                if let providers2 = json["TwoFactorProviders2"] as? [String: Any] {
                    let providerTypes = providers2.keys.compactMap { Int($0) }
                    if DebugConfig.isEnabled {
                        logger.debug("[debug] identityToken → 2FA required, providers: \(providerTypes, privacy: .public)")
                    }
                    throw IdentityTokenError.twoFactorRequired(providers: providerTypes)
                }
                // Invalid TOTP code or wrong password.
                if let errorDesc = json["error_description"] as? String {
                    if errorDesc.contains("Two-factor") || errorDesc.contains("two factor") {
                        if DebugConfig.isEnabled {
                            logger.debug("[debug] identityToken → 2FA code invalid (error_description match)")
                        }
                        throw IdentityTokenError.twoFactorCodeInvalid
                    }
                }
            }
            // Generic invalid_grant (wrong email/password).
            if DebugConfig.isEnabled {
                logger.debug("[debug] identityToken → invalidCredentials (generic 400)")
            }
            throw IdentityTokenError.invalidCredentials
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("HTTP \(http.statusCode) for \(request.url?.path ?? "unknown")")
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }

        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            if DebugConfig.isEnabled {
                // Log which fields are present — never log token values.
                let hasKey         = tokenResponse.key != nil
                let hasKdf         = tokenResponse.kdf != nil
                let hasUserId      = tokenResponse.userId != nil
                let hasEmail       = tokenResponse.email != nil
                let has2FA         = tokenResponse.twoFactorProviders != nil
                logger.debug("[debug] identityToken ← key=\(hasKey, privacy: .public) kdf=\(hasKdf, privacy: .public) userId=\(hasUserId, privacy: .public) email=\(hasEmail, privacy: .public) 2fa=\(has2FA, privacy: .public)")
            }
            return tokenResponse
        } catch {
            logger.error("Decoding failed for TokenResponse: \(error.localizedDescription)")
            if DebugConfig.isEnabled {
                let raw = String(data: data, encoding: .utf8) ?? "(binary)"
                logger.debug("[debug] TokenResponse raw body keys: \((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?.keys.sorted().joined(separator: ", ") ?? raw.prefix(300).description, privacy: .public)")
            }
            throw APIError.decodingFailed
        }
    }

    // MARK: - fetchSync

    func fetchSync() async throws -> SyncResponse {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        var components   = URLComponents(url: base.appendingPathComponent("api/sync"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "excludeDomains", value: "true")]
        let url          = components.url!

        if DebugConfig.isEnabled {
            logger.debug("[debug] fetchSync → GET \(url.absoluteString, privacy: .public) hasToken=\(self.accessToken != nil, privacy: .public)")
        }

        var request      = baseRequest(url: url)
        request.httpMethod = "GET"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let response: SyncResponse = try await perform(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] fetchSync ← ciphers=\(response.ciphers.count, privacy: .public) profileEmail=\(response.profile.email, privacy: .private) hasPrivateKey=\(response.profile.privateKey != nil, privacy: .public)")
        }
        return response
    }

    // MARK: - updateCipher

    func updateCipher(id: String, cipher: RawCipher) async throws -> RawCipher {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("api/ciphers/\(id)")

        if DebugConfig.isEnabled {
            logger.debug("[debug] updateCipher → PUT \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode the re-encrypted RawCipher as the request body.
        // Field values are already EncStrings — no plaintext leaves the device.
        request.httpBody = try JSONEncoder().encode(cipher)

        let updated: RawCipher = try await perform(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] updateCipher ← id=\(updated.id, privacy: .public)")
        }
        return updated
    }

    // MARK: - softDeleteCipher

    func softDeleteCipher(id: String) async throws {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("api/ciphers/\(id)")

        if DebugConfig.isEnabled {
            logger.debug("[debug] softDeleteCipher → DELETE \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        try await performEmpty(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] softDeleteCipher ← ok id=\(id, privacy: .public)")
        }
    }

    // MARK: - restoreCipher

    func restoreCipher(id: String) async throws {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("api/ciphers/\(id)/restore")

        if DebugConfig.isEnabled {
            logger.debug("[debug] restoreCipher → PUT \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // No body — the server identifies the cipher by URL path only.
        // Sending Content-Type: application/json with a body causes Vaultwarden to return 400.

        try await performEmpty(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] restoreCipher ← ok id=\(id, privacy: .public)")
        }
    }

    // MARK: - purgeTrashedCiphers

    func purgeTrashedCiphers() async throws {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("api/ciphers/purge")

        if DebugConfig.isEnabled {
            logger.debug("[debug] purgeTrashedCiphers → DELETE \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Empty JSON body — masterPasswordHash intentionally omitted in v1.
        // See TODO in MacwardenAPIClientProtocol.purgeTrashedCiphers for rationale.
        request.httpBody = Data("{}".utf8)

        try await performEmpty(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] purgeTrashedCiphers ← ok")
        }
    }

    // MARK: - refreshAccessToken

    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, refreshToken: String?) {
        guard let base = baseURL else { throw APIError.baseURLNotSet }
        let url = base.appendingPathComponent("identity/connect/token")

        if DebugConfig.isEnabled {
            logger.debug("[debug] refreshAccessToken → POST \(url.absoluteString, privacy: .public)")
        }

        let params: [String: String] = [
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
            "client_id":     ClientHeaders.clientId,
        ]

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded(params)

        let tokenResponse: TokenResponse = try await perform(request: request)
        accessToken = tokenResponse.accessToken

        if DebugConfig.isEnabled {
            logger.debug("[debug] refreshAccessToken ← new token obtained")
        }
        return (tokenResponse.accessToken, tokenResponse.refreshToken)
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
        if DebugConfig.isEnabled {
            logger.debug("[debug] perform [\(http.statusCode)] \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "", privacy: .public) responseBytes=\(data.count, privacy: .public)")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            // Scrub: do not log response body (may contain tokens or error details with PII).
            logger.error("HTTP \(http.statusCode) for \(request.url?.path ?? "unknown")")
            if DebugConfig.isEnabled {
                // Log only top-level JSON keys on error, never values.
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let keys = json.keys.sorted().joined(separator: ", ")
                    logger.debug("[debug] error body keys: [\(keys, privacy: .public)]")
                } else {
                    logger.debug("[debug] error body (non-JSON, \(data.count, privacy: .public) bytes)")
                }
            }
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            if DebugConfig.isEnabled {
                logger.debug("[debug] decoded \(T.self, privacy: .public) OK")
            }
            return decoded
        } catch {
            logger.error("Decoding failed for \(T.self): \(error.localizedDescription)")
            if DebugConfig.isEnabled {
                logger.debug("[debug] decode error detail: \(error, privacy: .public)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let keys = json.keys.sorted().joined(separator: ", ")
                    logger.debug("[debug] response body keys: [\(keys, privacy: .public)]")
                } else {
                    let snippet = String(data: data.prefix(500), encoding: .utf8) ?? "(binary)"
                    logger.debug("[debug] response body snippet: \(snippet, privacy: .public)")
                }
            }
            throw APIError.decodingFailed
        }
    }

    /// Sends `request` and checks the HTTP status code, discarding the response body.
    ///
    /// Used for endpoints that return 200/204 with no meaningful response body
    /// (soft-delete, restore, purge). Throws `APIError.httpError` on non-2xx responses.
    private func performEmpty(request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "")
        }

        logger.debug("[\(http.statusCode)] \(request.httpMethod ?? "?") \(request.url?.path ?? "")")

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("HTTP \(http.statusCode) for \(request.url?.path ?? "unknown")")
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    /// Character set safe for `application/x-www-form-urlencoded` values.
    ///
    /// Must be RFC 3986 unreserved characters only: `A-Z a-z 0-9 - _ . ~`
    /// `.urlQueryAllowed` is intentionally NOT used here because it permits `+`, `=`, and `&`,
    /// which are field separators in form encoding.  In particular, a `+` in a value is decoded
    /// as a space by all HTTP servers — this would silently corrupt a base64 password hash that
    /// contains `+` or ends with `=` padding.
    private static let formValueAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()

    /// Encodes a `[String: String]` dictionary as `application/x-www-form-urlencoded` data.
    private func formEncoded(_ params: [String: String]) -> Data {
        params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: Self.formValueAllowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: Self.formValueAllowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}
