import Foundation
import os.log

// MARK: - Protocol

/// Bitwarden REST API client for auth and vault sync operations.
///
/// All requests include the `X-Client-Version`, `Bitwarden-Client-Version`, and
/// `Bitwarden-Client-Name` headers. The identity token request additionally sends
/// `client_id` and `deviceType` as form parameters.
/// Reference: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
/// Missing or invalid headers result in `400 Bad Request` / `403 Forbidden` from the server.
///
/// Implemented as an `actor` to serialise the mutable `serverEnvironment` and `accessToken` state.
protocol PrizmAPIClientProtocol: Actor {

    /// The server environment configured by `AuthRepositoryImpl`.
    var serverEnvironment: ServerEnvironment? { get }

    /// Stores the server environment; determines per-service URLs and client identifier.
    func setServerEnvironment(_ env: ServerEnvironment)

    /// Stores the access token used for subsequent authenticated requests.
    func setAccessToken(_ token: String)

    /// Clears the in-memory access token.
    ///
    /// - Security goal: removes the bearer token from memory on sign-out so it cannot
    ///   be read from a heap dump after the session ends (Constitution §III).
    func clearAccessToken()

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
    ///   - newDeviceOTP:       One-time code from the user's email, if completing a new-device challenge.
    func identityToken(
        email:              String,
        passwordHash:       String,
        deviceIdentifier:   String,
        twoFactorToken:     String?,
        twoFactorProvider:  Int?,
        twoFactorRemember:  Bool,
        newDeviceOTP:       String?
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

    /// PUT `/api/ciphers/{id}/collections` — updates the collection membership of an org cipher.
    ///
    /// `PUT /api/ciphers/{id}` does not change collection assignments — this endpoint must be
    /// called separately whenever `collectionIds` changes. Passing an empty array moves the
    /// item to the org's Default collection.
    ///
    /// Reference: Bitwarden Server API PUT /api/ciphers/{id}/collections
    func updateCipherCollections(id: String, collectionIds: [String]) async throws

    /// PUT `/api/ciphers/{id}/delete` — soft-deletes a cipher by moving it to Trash.
    ///
    /// Sets `deletedDate` on the server. The item remains in the user's vault data and
    /// can be restored. Bitwarden cloud auto-purges trashed items after 30 days server-side;
    /// self-hosted Vaultwarden only auto-purges if `TRASH_AUTO_DELETE_DAYS` is configured.
    ///
    /// Note: `DELETE /api/ciphers/{id}` is the *permanent* delete endpoint — do NOT use it
    /// for soft-delete. The soft-delete endpoint is `PUT /api/ciphers/{id}/delete`.
    ///
    /// Reference: Bitwarden Server API PUT /api/ciphers/{id}/delete
    func softDeleteCipher(id: String) async throws

    /// DELETE `/api/ciphers/{id}` — permanently deletes a cipher.
    ///
    /// **Irreversible.** Removes the cipher from the server entirely.
    /// Used only when deleting an item that is already in Trash.
    ///
    /// Reference: Bitwarden Server API DELETE /api/ciphers/{id}
    func permanentDeleteCipher(id: String) async throws

    /// PUT `/api/ciphers/{id}/restore` — restores a trashed cipher to the active vault.
    ///
    /// Clears `deletedDate` on the server. The item becomes visible in the active vault again.
    ///
    /// Reference: Bitwarden Server API PUT /api/ciphers/{id}/restore
    func restoreCipher(id: String) async throws

    /// POST `/api/ciphers` — creates a new cipher with encrypted field values.
    ///
    /// Requires a valid `Authorization: Bearer <accessToken>` header.
    /// The request body is a JSON-encoded `RawCipher`. The server assigns the ID and timestamps.
    /// On success the server returns the created cipher, decoded back into `RawCipher`.
    func createCipher(cipher: RawCipher) async throws -> RawCipher

    /// POST `/api/ciphers/create` — creates an org-scoped cipher.
    ///
    /// Used for items belonging to an organization (when `cipher.organizationId != nil`).
    /// The body must include `collectionIds[]` so the server assigns the item to the
    /// specified collections.
    ///
    /// Reference: Bitwarden Server API POST /api/ciphers/create
    func createOrgCipher(cipher: RawCipher) async throws -> RawCipher

    // MARK: - Attachment endpoints

    /// POST `/api/ciphers/{cipherId}/attachment/v2` — creates attachment metadata on the server.
    ///
    /// Returns the attachment ID, a signed upload URL (or Bitwarden-hosted URL for fileUploadType 0),
    /// and the file upload type (0 = Bitwarden-hosted, 1 = Azure blob storage).
    ///
    /// Reference: Bitwarden Server API POST /api/ciphers/{id}/attachment/v2
    func createAttachmentMetadata(cipherId: String, body: AttachmentMetadataRequest) async throws -> AttachmentMetadataResponse

    /// POST `/api/ciphers/{cipherId}/attachment/{attachmentId}` — uploads a file blob via multipart.
    ///
    /// Used when `fileUploadType == 0` (Bitwarden-hosted storage).
    /// The encrypted blob is sent as the `data` field of a multipart/form-data body.
    func uploadAttachmentBitwardenHosted(cipherId: String, attachmentId: String, encryptedBlob: Data) async throws

    /// PUT `<signedURL>` with `x-ms-blob-type: BlockBlob` — uploads to Azure Blob Storage.
    ///
    /// Used when `fileUploadType == 1` (Azure). The signed URL is provided by the v2 metadata response.
    /// The request body is the raw encrypted blob with the Azure-required header.
    func uploadAttachmentAzure(signedURL: URL, encryptedBlob: Data) async throws

    /// GET `/api/ciphers/{cipherId}/attachment/{attachmentId}` — fetches a fresh signed download URL.
    ///
    /// Returns an `AttachmentDownloadResponse` containing the signed URL valid for a limited time.
    /// Called when `Attachment.url` is nil or returns HTTP 403.
    func fetchAttachmentDownloadURL(cipherId: String, attachmentId: String) async throws -> AttachmentDownloadResponse

    /// DELETE `/api/ciphers/{cipherId}/attachment/{attachmentId}` — deletes an attachment.
    func deleteAttachment(cipherId: String, attachmentId: String) async throws

    /// GET `<signedURL>` — downloads the raw encrypted blob from a signed URL.
    ///
    /// Used by `AttachmentRepositoryImpl` to fetch attachment blobs. Routed through the
    /// API client (rather than `URLSession.shared`) so tests can mock the download path
    /// and the shared session configuration (timeouts, etc.) is applied.
    func downloadBlob(from url: URL) async throws -> Data

    // MARK: - Folder CRUD

    /// POST `/api/folders` — creates a new folder with an encrypted name.
    func createFolder(encryptedName: String) async throws -> RawFolder

    /// PUT `/api/folders/{id}` — renames a folder with an encrypted name.
    func updateFolder(id: String, encryptedName: String) async throws -> RawFolder

    /// DELETE `/api/folders/{id}` — permanently deletes a folder.
    /// Items in the folder are unfoldered, not deleted.
    func deleteFolder(id: String) async throws

    // MARK: - Cipher partial / move

    /// PUT `/ciphers/{id}/partial` — updates folderId and favorite without re-encrypting.
    func updateCipherPartial(id: String, folderId: String?, favorite: Bool) async throws

    /// PUT `/ciphers/move` — bulk-moves ciphers to a folder.
    func moveCiphersToFolder(ids: [String], folderId: String?) async throws

    // MARK: - Collection CRUD

    /// POST `/api/organizations/{orgId}/collections` — creates a new collection.
    ///
    /// - Parameters:
    ///   - organizationId: The org the collection belongs to.
    ///   - encryptedName: The collection name encrypted with the org's symmetric key.
    func createCollection(organizationId: String, encryptedName: String) async throws -> RawCollection

    /// PUT `/api/organizations/{orgId}/collections/{id}` — renames an existing collection.
    func renameCollection(id: String, organizationId: String, encryptedName: String) async throws -> RawCollection

    /// DELETE `/api/organizations/{orgId}/collections/{id}` — deletes a collection.
    func deleteCollection(id: String, organizationId: String) async throws

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
/// The Bitwarden identity service returns HTTP 400 for both wrong passwords, 2FA challenges,
/// and new-device OTP requirements; `IdentityTokenError` models the meaningful distinctions
/// so the repository layer can act on them.
nonisolated enum IdentityTokenError: Error, Equatable {
    /// The server requires two-factor authentication before issuing a token.
    /// `providers` is the list of available 2FA type numbers (0 = authenticatorApp, etc.).
    case twoFactorRequired(providers: [Int])
    /// The submitted TOTP code (or remember-device token) was rejected by the server.
    case twoFactorCodeInvalid
    /// Email or password is incorrect (HTTP 400 `invalid_grant` without 2FA challenge).
    case invalidCredentials
    /// The server does not recognise this device and has dispatched a one-time code
    /// to the user's registered email. Trigger: HTTP 400, `{"error": "device_error"}`.
    /// `error_description` is informational only and SHALL NOT be used as the trigger condition.
    case newDeviceNotVerified
}

// MARK: - Errors

/// Errors thrown by `PrizmAPIClientImpl` at the transport layer.
///
/// Higher-level semantic errors (e.g. `.invalidCredentials`, `.unauthorized`) are mapped
/// by the repository layer (`AuthRepositoryImpl`, `SyncRepositoryImpl`) from these raw codes.
nonisolated enum APIError: Error, Equatable {
    /// The HTTP response status code indicates failure.
    case httpError(statusCode: Int, body: String)
    /// The response body could not be decoded into the expected type.
    case decodingFailed
    /// `setServerEnvironment` was never called before making a request.
    case serverEnvironmentNotSet
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let body):
            return body.isEmpty ? "Server error \(statusCode)." : "Server error \(statusCode): \(body)"
        case .decodingFailed:
            return "The server response could not be read. Please try again."
        case .serverEnvironmentNotSet:
            return "No server URL is configured."
        }
    }
}

// MARK: - Attachment wire models

/// Request body for POST `/api/ciphers/{id}/attachment/v2`.
///
/// `fileName` is an EncString (encrypted). `key` is the per-attachment key wrapped as
/// an EncString. Both are produced by `AttachmentRepositoryImpl` before sending.
///
/// Reference: Bitwarden Server API POST /api/ciphers/{id}/attachment/v2
nonisolated struct AttachmentMetadataRequest: Encodable {
    let fileName:     String    // EncString
    let key:          String    // EncString — per-attachment key wrapped with cipher key
    let fileSize:     Int
    let adminRequest: Bool      // always false for personal vault

    // Server expects camelCase — synthesized Encodable matches.
}

/// Response from POST `/api/ciphers/{id}/attachment/v2`.
///
/// `fileUploadType`: 0 = Bitwarden-hosted (POST to API), 1 = Azure (PUT to signed URL).
/// `url` is the signed upload destination (Azure) or the API upload endpoint (Bitwarden-hosted).
/// `attachmentId` is the server-assigned ID for the new attachment.
nonisolated struct AttachmentMetadataResponse: Decodable {
    let attachmentId:   String
    let url:            String
    let fileUploadType: Int
}

/// Response from GET `/api/ciphers/{id}/attachment/{attachmentId}`.
///
/// Contains a fresh signed download URL for the encrypted blob.
nonisolated struct AttachmentDownloadResponse: Decodable {
    let url: String
}

// MARK: - Implementation

/// URLSession-backed Bitwarden API client.
///
/// All requests include the required Bitwarden client identification headers:
/// - `X-Client-Version: "2024.12.0"` (version string, required by upstream Bitwarden)
/// - `Bitwarden-Client-Version: "2024.12.0"` (>= 2024.12.0 required for SSH key support on Vaultwarden)
/// - `Bitwarden-Client-Name: "desktop"` (required by Bitwarden Cloud — ADR-0023)
///
/// The identity token request additionally sends these as form body parameters:
/// - `client_id`: Prizm's registered identifier for cloud accounts, `"desktop"` for self-hosted
/// - `deviceType: "7"`  (7 = macOS desktop, per Bitwarden DeviceType enum)
///
/// Header requirements: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
/// DeviceType enum values: https://github.com/bitwarden/server/blob/main/src/Core/Enums/DeviceType.cs
actor PrizmAPIClientImpl: PrizmAPIClientProtocol {

    // MARK: - Private state

    private(set) var serverEnvironment: ServerEnvironment?
    private var accessToken: String?
    /// Per-environment client identifier; cloud = registered Prizm ID, self-hosted = "desktop".
    private var clientId: String = "desktop"

    private let session:   URLSession
    private let logger:    Logger = Logger(
        subsystem: "com.prizm",
        category:  "PrizmAPIClient"
    )

    // MARK: - Bitwarden client identification headers
    // These are mandatory on every request to the Bitwarden identity + API services.
    // deviceType 7 = macOS desktop per the Bitwarden DeviceType enum:
    // https://github.com/bitwarden/server/blob/main/src/Core/Enums/DeviceType.cs
    private enum ClientHeaders {
        // Vaultwarden gates SSH key ciphers (type 5) behind >= 2024.12.0.
        static let clientVersion = "2024.12.0"
        static let deviceType    = "7"
        static let userAgent     = "Prizm/2024.12.0"
    }

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Configuration

    func setServerEnvironment(_ env: ServerEnvironment) {
        serverEnvironment = env
        // Bitwarden Cloud password grant (grant_type=password) requires client_id to be one
        // of Bitwarden's own registered OAuth client names ("desktop", "web", "mobile", etc.).
        // The UUID in Config.bitwardenClientIdentifier is for API key auth (client_credentials)
        // only — using it for password grant returns invalid_client on both US and EU.
        // "desktop" is accepted by both regions and is the conventional choice for native apps.
        clientId = "desktop"
    }

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    func clearAccessToken() {
        accessToken = nil
    }

    // MARK: - preLogin

    func preLogin(email: String) async throws -> PreLoginResponse {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        // prelogin is served by the identity service, not the API service — despite the
        // /accounts/ prefix suggesting otherwise. Using apiURL returns 404 on both regions.
        // POST https://identity.bitwarden.{com,eu}/accounts/prelogin → 200 ✓
        // POST https://api.bitwarden.{com,eu}/accounts/prelogin       → 404 ✗
        let url = env.identityURL.appendingPathComponent("accounts/prelogin")

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
        twoFactorRemember: Bool,
        newDeviceOTP:      String? = nil
    ) async throws -> TokenResponse {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.identityURL.appendingPathComponent("connect/token")

        logger.info("identityToken → POST \(env.identityURL.absoluteString, privacy: .public)")

        if DebugConfig.isEnabled {
            let isTOTP = twoFactorToken != nil
            let isOTP  = newDeviceOTP != nil
            logger.debug("[debug] identityToken → POST \(url.absoluteString, privacy: .public) 2FA=\(isTOTP, privacy: .public) provider=\(twoFactorProvider.map(String.init) ?? "nil", privacy: .public) newDeviceOTP=\(isOTP, privacy: .public)")
        }

        var params: [String: String] = [
            "grant_type":      "password",
            "username":        email,
            "password":        passwordHash,
            "scope":           "api offline_access",
            "client_id":       clientId,
            "deviceType":      ClientHeaders.deviceType,
            "deviceIdentifier": deviceIdentifier,
            "deviceName":      "Prizm",
        ]
        if let token    = twoFactorToken    { params["twoFactorToken"]    = token }
        if let provider = twoFactorProvider { params["twoFactorProvider"] = String(provider) }
        if twoFactorRemember                { params["twoFactorRemember"] = "true" }
        if let otp      = newDeviceOTP      { params["newdeviceotp"]      = otp }

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
    /// The Bitwarden identity service overloads HTTP 400 for four distinct outcomes —
    /// disambiguation requires inspecting the response body:
    ///   1. 2FA challenge: body contains `"TwoFactorProviders2"` key → throw `.twoFactorRequired`
    ///   2. Bad TOTP code: `error_description` contains "Two-factor" → throw `.twoFactorCodeInvalid`
    ///   3. New device verification: `"error": "device_error"` → throw `.newDeviceNotVerified`
    ///   4. Wrong password: generic `invalid_grant` body → throw `.invalidCredentials`
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
                    if let errorVal = json["error"] as? String {
                        logger.debug("[debug] identityToken 400 error: \(errorVal, privacy: .public)")
                    }
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
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 2FA challenge: server returns TwoFactorProviders2 dict with available providers.
                if let providers2 = json["TwoFactorProviders2"] as? [String: Any] {
                    let providerTypes = providers2.keys.compactMap { Int($0) }
                    if DebugConfig.isEnabled {
                        logger.debug("[debug] identityToken → 2FA required, providers: \(providerTypes, privacy: .public)")
                    }
                    throw IdentityTokenError.twoFactorRequired(providers: providerTypes)
                }
                // New device OTP required: server returns {"error": "device_error"}.
                // Only the `error` field is checked — `error_description` is informational only
                // and is not stable across server versions.
                if let errorField = json["error"] as? String, errorField == "device_error" {
                    logger.info("New device OTP required (device_error response)")
                    throw IdentityTokenError.newDeviceNotVerified
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
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        var components = URLComponents(
            url: env.apiURL.appendingPathComponent("sync"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "excludeDomains", value: "true")]
        let url = components.url!

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
            logger.debug("[debug] fetchSync ← ciphers=\(response.ciphers.count, privacy: .public) folders=\(response.folders.count, privacy: .public) profileEmail=\(response.profile.email, privacy: .private) hasPrivateKey=\(response.profile.privateKey != nil, privacy: .public)")
        }
        return response
    }

    // MARK: - updateCipher

    func updateCipher(id: String, cipher: RawCipher) async throws -> RawCipher {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/\(id)")

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

    // MARK: - updateCipherCollections

    func updateCipherCollections(id: String, collectionIds: [String]) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/\(id)/collections")
        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = ["collectionIds": collectionIds]
        request.httpBody = try JSONEncoder().encode(body)
        try await performEmpty(request: request)
    }

    // MARK: - softDeleteCipher

    func softDeleteCipher(id: String) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        // PUT /ciphers/{id}/delete — soft-delete (moves to Trash, sets deletedDate).
        // Do NOT use DELETE /ciphers/{id} here; that endpoint permanently removes the cipher.
        let url = env.apiURL.appendingPathComponent("ciphers/\(id)/delete")

        if DebugConfig.isEnabled {
            logger.debug("[debug] softDeleteCipher → PUT \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        try await performEmpty(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] softDeleteCipher ← ok id=\(id, privacy: .public)")
        }
    }

    // MARK: - permanentDeleteCipher

    func permanentDeleteCipher(id: String) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/\(id)")

        if DebugConfig.isEnabled {
            logger.debug("[debug] permanentDeleteCipher → DELETE \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        try await performEmpty(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] permanentDeleteCipher ← ok id=\(id, privacy: .public)")
        }
    }

    // MARK: - restoreCipher

    func restoreCipher(id: String) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/\(id)/restore")

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

    // MARK: - createAttachmentMetadata

    func createAttachmentMetadata(cipherId: String, body: AttachmentMetadataRequest) async throws -> AttachmentMetadataResponse {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL
            .appendingPathComponent("ciphers")
            .appendingPathComponent(cipherId)
            .appendingPathComponent("attachment/v2")
        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request: request)
    }

    // MARK: - uploadAttachmentBitwardenHosted

    func uploadAttachmentBitwardenHosted(cipherId: String, attachmentId: String, encryptedBlob: Data) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL
            .appendingPathComponent("ciphers")
            .appendingPathComponent(cipherId)
            .appendingPathComponent("attachment")
            .appendingPathComponent(attachmentId)

        // Multipart/form-data with a single `data` field containing the encrypted blob.
        let boundary = UUID().uuidString
        var multipart = Data()
        multipart.append("--\(boundary)\r\n".data(using: .utf8)!)
        multipart.append("Content-Disposition: form-data; name=\"data\"; filename=\"attachment\"\r\n".data(using: .utf8)!)
        multipart.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        multipart.append(encryptedBlob)
        multipart.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = multipart
        try await performEmpty(request: request)
    }

    // MARK: - uploadAttachmentAzure

    func uploadAttachmentAzure(signedURL: URL, encryptedBlob: Data) async throws {
        // Azure Blob Storage requires `x-ms-blob-type: BlockBlob` on PUT uploads.
        // Reference: https://learn.microsoft.com/en-us/rest/api/storageservices/put-blob
        var request = URLRequest(url: signedURL)
        request.httpMethod = "PUT"
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = encryptedBlob
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.httpError(statusCode: code, body: "Azure upload failed")
        }
    }

    // MARK: - fetchAttachmentDownloadURL

    func fetchAttachmentDownloadURL(cipherId: String, attachmentId: String) async throws -> AttachmentDownloadResponse {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL
            .appendingPathComponent("ciphers")
            .appendingPathComponent(cipherId)
            .appendingPathComponent("attachment")
            .appendingPathComponent(attachmentId)
        var request = baseRequest(url: url)
        request.httpMethod = "GET"
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request: request)
    }

    // MARK: - deleteAttachment

    func deleteAttachment(cipherId: String, attachmentId: String) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL
            .appendingPathComponent("ciphers")
            .appendingPathComponent(cipherId)
            .appendingPathComponent("attachment")
            .appendingPathComponent(attachmentId)
        var request = baseRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = accessToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        try await performEmpty(request: request)
    }

    // MARK: - downloadBlob

    func downloadBlob(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, body: "")
        }
        return data
    }

    // MARK: - createCipher

    func createCipher(cipher: RawCipher) async throws -> RawCipher {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers")

        if DebugConfig.isEnabled {
            logger.debug("[debug] createCipher → POST \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(cipher)

        let created: RawCipher = try await perform(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] createCipher ← id=\(created.id, privacy: .public)")
        }
        return created
    }

    // MARK: - createOrgCipher

    /// Wrapper body for `POST /ciphers/create` — Bitwarden expects `{ "cipher": ..., "collectionIds": [...] }`.
    private struct OrgCipherCreateRequest: Encodable {
        let cipher: RawCipher
        let collectionIds: [String]
    }

    func createOrgCipher(cipher: RawCipher) async throws -> RawCipher {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/create")

        if DebugConfig.isEnabled {
            logger.debug("[debug] createOrgCipher → POST \(url.absoluteString, privacy: .public)")
        }

        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = OrgCipherCreateRequest(cipher: cipher, collectionIds: cipher.collectionIds)
        request.httpBody = try JSONEncoder().encode(body)

        let created: RawCipher = try await perform(request: request)
        if DebugConfig.isEnabled {
            logger.debug("[debug] createOrgCipher ← id=\(created.id, privacy: .public)")
        }
        return created
    }

    // MARK: - Folder CRUD

    func createFolder(encryptedName: String) async throws -> RawFolder {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("folders")
        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(["name": encryptedName])
        return try await perform(request: request)
    }

    func updateFolder(id: String, encryptedName: String) async throws -> RawFolder {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("folders/\(id)")
        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(["name": encryptedName])
        return try await perform(request: request)
    }

    func deleteFolder(id: String) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("folders/\(id)")
        var request = baseRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        try await performEmpty(request: request)
    }

    // MARK: - Collection CRUD

    /// Bitwarden collection body for create/rename — `groups` and `users` default to empty.
    private struct CollectionBody: Encodable {
        let name: String
        let groups: [String]
        let users: [String]
    }

    func createCollection(organizationId: String, encryptedName: String) async throws -> RawCollection {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("organizations/\(organizationId)/collections")
        var request = baseRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(CollectionBody(name: encryptedName, groups: [], users: []))
        return try await perform(request: request)
    }

    func renameCollection(id: String, organizationId: String, encryptedName: String) async throws -> RawCollection {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("organizations/\(organizationId)/collections/\(id)")
        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(CollectionBody(name: encryptedName, groups: [], users: []))
        return try await perform(request: request)
    }

    func deleteCollection(id: String, organizationId: String) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("organizations/\(organizationId)/collections/\(id)")
        var request = baseRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        try await performEmpty(request: request)
    }

    // MARK: - Cipher partial / move

    func updateCipherPartial(id: String, folderId: String?, favorite: Bool) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/\(id)/partial")
        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body: [String: Any] = ["favorite": favorite]
        body["folderId"] = folderId as Any
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try await performEmpty(request: request)
    }

    func moveCiphersToFolder(ids: [String], folderId: String?) async throws {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.apiURL.appendingPathComponent("ciphers/move")
        var request = baseRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body: [String: Any] = ["ids": ids]
        if let folderId { body["folderId"] = folderId }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try await performEmpty(request: request)
    }

    // MARK: - refreshAccessToken

    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, refreshToken: String?) {
        guard let env = serverEnvironment else { throw APIError.serverEnvironmentNotSet }
        let url = env.identityURL.appendingPathComponent("connect/token")

        if DebugConfig.isEnabled {
            logger.debug("[debug] refreshAccessToken → POST \(url.absoluteString, privacy: .public)")
        }

        let params: [String: String] = [
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
            "client_id":     clientId,
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
        req.setValue(ClientHeaders.clientVersion, forHTTPHeaderField: "Bitwarden-Client-Version")
        req.setValue(Config.clientName,           forHTTPHeaderField: "Bitwarden-Client-Name")
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
