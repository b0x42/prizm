import Foundation
import os.log

// MARK: - AuthRepositoryImpl

/// Concrete implementation of `AuthRepository`.
///
/// Orchestrates the full Bitwarden login flow:
///   1. POST `/accounts/prelogin` → KDF params
///   2. Derive master key (PBKDF2 or Argon2id) locally
///   3. POST `/connect/token` → access + refresh tokens
///   4. Decrypt encUserKey → vault symmetric keys
///   5. Unlock `BitwardenCryptoServiceImpl` with vault keys
///   6. Persist tokens + metadata in Keychain
///
/// Two-factor flow: `loginWithPassword` returns `.requiresTwoFactor` and stores
/// pending state in-memory; `loginWithTOTP` completes the challenge.
///
/// Thread safety: all mutable state is read/written on the calling actor.
/// `@MainActor` annotation ensures single-threaded access during tests and UI.
@MainActor
final class AuthRepositoryImpl: AuthRepository {

    // MARK: - Dependencies

    private let apiClient:  any BitwardenAPIClientProtocol
    private let crypto:     any BitwardenCryptoService
    private let keychain:   any KeychainService

    private let logger = Logger(subsystem: "com.bitwarden-macos", category: "AuthRepository")

    // MARK: - Server configuration

    private(set) var serverEnvironment: ServerEnvironment?

    // MARK: - Pending 2FA state
    // Set by loginWithPassword when the server requests 2FA; consumed by loginWithTOTP.

    private struct PendingTwoFactor {
        let email:        String
        let passwordHash: String
        let kdfParams:    KdfParams
        let stretchedKeys: CryptoKeys
        let deviceId:     String
    }
    private var pendingTwoFactor: PendingTwoFactor?

    // MARK: - Init

    init(
        apiClient: any BitwardenAPIClientProtocol,
        crypto:    any BitwardenCryptoService,
        keychain:  any KeychainService
    ) {
        self.apiClient = apiClient
        self.crypto    = crypto
        self.keychain  = keychain
    }

    // MARK: - Server configuration

    func validateServerURL(_ urlString: String) throws {
        // Strip trailing slash for normalisation.
        let trimmed = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            throw AuthError.invalidURL
        }
    }

    func setServerEnvironment(_ environment: ServerEnvironment) async throws {
        serverEnvironment = environment
        await apiClient.setBaseURL(environment.base)
    }

    // MARK: - Login

    func loginWithPassword(email: String, masterPassword: String) async throws -> LoginResult {
        logger.info("Login attempt for \(email, privacy: .private)")
        guard let env = serverEnvironment else {
            throw AuthError.serverUnreachable
        }

        // Step 1: Fetch KDF params.
        logger.info("Step 1: fetching KDF params for \(email, privacy: .private)")
        let preLogin   = try await apiClient.preLogin(email: email)
        let kdfParams  = preLogin.kdfParams
        if DebugConfig.isEnabled {
            logger.debug("[debug] KDF params → type=\(String(describing: kdfParams.type), privacy: .public) iterations=\(kdfParams.iterations, privacy: .public) memory=\(kdfParams.memory.map(String.init) ?? "nil", privacy: .public) parallelism=\(kdfParams.parallelism.map(String.init) ?? "nil", privacy: .public)")
        }

        // Step 2: Derive master key locally — never sent to server.
        logger.info("Step 2: deriving master key (KDF)")
        let masterKey  = try await crypto.makeMasterKey(
            password: masterPassword,
            email:    email.lowercased(),
            kdf:      kdfParams
        )
        if DebugConfig.isEnabled {
            logger.debug("[debug] master key derived (\(masterKey.count, privacy: .public) bytes)")
        }

        // Step 3: Stretch master key into separate enc + mac keys (HKDF).
        logger.info("Step 3: stretching master key (HKDF)")
        let stretched  = try await crypto.stretchKey(masterKey: masterKey)
        if DebugConfig.isEnabled {
            logger.debug("[debug] stretched key: encKey=\(stretched.encryptionKey.count, privacy: .public) bytes, macKey=\(stretched.macKey.count, privacy: .public) bytes")
        }

        // Step 4: Compute server authentication hash.
        // Per Bitwarden Security Whitepaper §4: the hash proves knowledge of the
        // master password without revealing the master key itself.
        logger.info("Step 4: computing server authentication hash")
        let serverHash = try await crypto.makeServerHash(
            masterKey: masterKey,
            password:  masterPassword
        )
        if DebugConfig.isEnabled {
            logger.debug("[debug] server hash computed (\(serverHash.count, privacy: .public) chars)")
        }

        // Step 5: Request identity token.
        logger.info("Step 5: requesting identity token")
        let deviceId   = try deviceIdentifier()
        let tokenResp: TokenResponse
        do {
            tokenResp = try await apiClient.identityToken(
                email:             email,
                passwordHash:      serverHash,
                deviceIdentifier:  deviceId,
                twoFactorToken:    nil,
                twoFactorProvider: nil,
                twoFactorRemember: false
            )
        } catch let err as IdentityTokenError {
            switch err {
            case .twoFactorRequired(let providers):
                pendingTwoFactor = PendingTwoFactor(
                    email:         email,
                    passwordHash:  serverHash,
                    kdfParams:     kdfParams,
                    stretchedKeys: stretched,
                    deviceId:      deviceId
                )
                logger.info("2FA required")
                return .requiresTwoFactor(twoFactorMethod(from: providers))
            case .twoFactorCodeInvalid:
                logger.error("Login failed: \(AuthError.invalidTwoFactorCode.localizedDescription, privacy: .public)")
                throw AuthError.invalidTwoFactorCode
            case .invalidCredentials:
                logger.error("Login failed: \(AuthError.invalidCredentials.localizedDescription, privacy: .public)")
                throw AuthError.invalidCredentials
            }
        }

        if let providers = tokenResp.twoFactorProviders, !providers.isEmpty {
            // Server returned a 2FA challenge inside a 200 response (test-mock path).
            pendingTwoFactor = PendingTwoFactor(
                email:         email,
                passwordHash:  serverHash,
                kdfParams:     kdfParams,
                stretchedKeys: stretched,
                deviceId:      deviceId
            )
            logger.info("2FA required")
            return .requiresTwoFactor(twoFactorMethod(from: providers))
        }

        // Step 6: Finalize the session with the token response.
        logger.info("Step 6: finalizing session")
        if DebugConfig.isEnabled {
            logger.debug("[debug] token response fields present → key=\(tokenResp.key != nil, privacy: .public) kdf=\(tokenResp.kdf != nil, privacy: .public) userId=\(tokenResp.userId != nil, privacy: .public) email=\(tokenResp.email != nil, privacy: .public) refreshToken=\(tokenResp.refreshToken != nil, privacy: .public)")
        }
        let account = try await finalizeSession(
            tokenResp:    tokenResp,
            stretched:    stretched,
            environment:  env
        )
        logger.info("Login succeeded")
        return .success(account)
    }

    func loginWithTOTP(code: String, rememberDevice: Bool) async throws -> Account {
        logger.info("Submitting TOTP code")
        guard let pending = pendingTwoFactor,
              let env     = serverEnvironment else {
            throw AuthError.invalidCredentials
        }

        let tokenResp: TokenResponse
        do {
            tokenResp = try await apiClient.identityToken(
                email:             pending.email,
                passwordHash:      pending.passwordHash,
                deviceIdentifier:  pending.deviceId,
                twoFactorToken:    code,
                twoFactorProvider: 0,   // authenticatorApp
                twoFactorRemember: rememberDevice
            )
        } catch let err as IdentityTokenError {
            switch err {
            case .twoFactorCodeInvalid:
                logger.error("Login failed: \(AuthError.invalidTwoFactorCode.localizedDescription, privacy: .public)")
                throw AuthError.invalidTwoFactorCode
            case .invalidCredentials:
                logger.error("Login failed: \(AuthError.invalidTwoFactorCode.localizedDescription, privacy: .public)")
                throw AuthError.invalidTwoFactorCode   // TOTP wrong code maps to same user-visible error
            case .twoFactorRequired:
                logger.error("Login failed: \(AuthError.invalidTwoFactorCode.localizedDescription, privacy: .public)")
                throw AuthError.invalidTwoFactorCode
            }
        }

        pendingTwoFactor = nil
        logger.info("TOTP accepted")
        return try await finalizeSession(
            tokenResp:   tokenResp,
            stretched:   pending.stretchedKeys,
            environment: env
        )
    }

    // MARK: - Unlock

    func unlockWithPassword(_ masterPassword: String) async throws -> Account {
        logger.info("Unlock attempt")
        let userId: String
        do {
            userId = try readString(key: KeychainKey.activeUserId)
        } catch {
            logger.error("No active user ID in Keychain: \(error.localizedDescription, privacy: .public)")
            throw AuthError.invalidCredentials
        }

        let emailKey  = KeychainKey.user(userId, "email")
        let kdfKey    = KeychainKey.user(userId, "kdfParams")
        let encKeyKey = KeychainKey.user(userId, "encUserKey")

        let email: String
        let kdfJSON: String
        let encUserKey: String
        do {
            email      = try readString(key: emailKey)
            kdfJSON    = try readString(key: kdfKey)
            encUserKey = try readString(key: encKeyKey)
        } catch {
            logger.error("Missing session data in Keychain: \(error.localizedDescription, privacy: .public)")
            throw AuthError.invalidCredentials
        }

        guard let kdfData = kdfJSON.data(using: .utf8) else {
            logger.error("KDF params not valid UTF-8")
            throw AuthError.invalidCredentials
        }
        let kdfParams: KdfParams
        do {
            kdfParams = try JSONDecoder().decode(KdfParams.self, from: kdfData)
        } catch {
            logger.error("KDF params decode failed: \(error.localizedDescription, privacy: .public)")
            throw AuthError.invalidCredentials
        }

        if DebugConfig.isEnabled {
            logger.debug("[debug] unlock: KDF type=\(String(describing: kdfParams.type), privacy: .public) iterations=\(kdfParams.iterations, privacy: .public) encUserKey prefix=\(String(encUserKey.prefix(2)), privacy: .public)")
        }
        let masterKey  = try await crypto.makeMasterKey(
            password: masterPassword,
            email:    email.lowercased(),
            kdf:      kdfParams
        )
        let stretched  = try await crypto.stretchKey(masterKey: masterKey)
        let vaultKeys  = try await crypto.decryptSymmetricKey(
            encUserKey:    encUserKey,
            stretchedKeys: stretched
        )
        await crypto.unlockWith(keys: vaultKeys)

        logger.info("Unlock succeeded")
        return try account(for: userId)
    }

    // MARK: - Session

    func storedAccount() -> Account? {
        guard let userId = try? readString(key: KeychainKey.activeUserId) else {
            logger.debug("No stored account — activeUserId not found")
            return nil
        }
        do {
            return try account(for: userId)
        } catch {
            logger.error("Failed to reconstruct account for stored userId: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func signOut() async throws {
        logger.info("Signing out — clearing session data")
        let userId: String
        do {
            userId = try readString(key: KeychainKey.activeUserId)
        } catch {
            logger.debug("No active userId during sign-out (may already be cleared)")
            userId = ""
        }

        // Clear per-user keys first — best-effort, log failures.
        if !userId.isEmpty {
            for suffix in ["accessToken", "refreshToken", "encUserKey", "kdfParams",
                           "email", "name", "serverEnvironment"] {
                do {
                    try keychain.delete(key: KeychainKey.user(userId, suffix))
                } catch {
                    logger.debug("Keychain delete \(suffix) skipped: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        // Clear global key last.
        do {
            try keychain.delete(key: KeychainKey.activeUserId)
        } catch {
            logger.debug("activeUserId delete skipped: \(error.localizedDescription, privacy: .public)")
        }

        await crypto.lockVault()
        serverEnvironment = nil
        pendingTwoFactor  = nil
    }

    // MARK: - Lock

    func lockVault() async {
        await crypto.lockVault()
    }

    // MARK: - Private helpers

    /// Completes a successful token exchange: decrypts vault key, stores credentials, returns Account.
    private func finalizeSession(
        tokenResp:   TokenResponse,
        stretched:   CryptoKeys,
        environment: ServerEnvironment
    ) async throws -> Account {
        if DebugConfig.isEnabled {
            logger.debug("[debug] finalizeSession: userId=\(tokenResp.userId != nil, privacy: .public) email=\(tokenResp.email != nil, privacy: .public) key=\(tokenResp.key != nil, privacy: .public) accessToken.isEmpty=\(tokenResp.accessToken.isEmpty, privacy: .public) refreshToken=\(tokenResp.refreshToken != nil, privacy: .public)")
        }
        guard let userId   = tokenResp.userId,
              let email    = tokenResp.email,
              let encKey   = tokenResp.key,
              let accessToken  = tokenResp.accessToken.isEmpty ? nil : tokenResp.accessToken,
              let refreshToken = tokenResp.refreshToken else {
            logger.error("finalizeSession: missing required token fields — userId=\(tokenResp.userId != nil, privacy: .public) email=\(tokenResp.email != nil, privacy: .public) key=\(tokenResp.key != nil, privacy: .public) accessTokenNonEmpty=\(!tokenResp.accessToken.isEmpty, privacy: .public) refreshToken=\(tokenResp.refreshToken != nil, privacy: .public)")
            throw AuthError.invalidCredentials
        }
        logger.info("Session finalized for user \(userId, privacy: .private)")

        // Decrypt the encrypted user key using the stretched master keys.
        if DebugConfig.isEnabled {
            logger.debug("[debug] decrypting encUserKey (type prefix: \(String(encKey.prefix(2)), privacy: .public))")
        }
        let vaultKeys = try await crypto.decryptSymmetricKey(
            encUserKey:    encKey,
            stretchedKeys: stretched
        )
        if DebugConfig.isEnabled {
            logger.debug("[debug] vault keys decrypted — encKey=\(vaultKeys.encryptionKey.count, privacy: .public) bytes, macKey=\(vaultKeys.macKey.count, privacy: .public) bytes")
        }
        await crypto.unlockWith(keys: vaultKeys)

        // Persist session data in Keychain.
        try writeString(userId,       key: KeychainKey.activeUserId)
        try writeString(accessToken,  key: KeychainKey.user(userId, "accessToken"))
        try writeString(refreshToken, key: KeychainKey.user(userId, "refreshToken"))
        try writeString(encKey,       key: KeychainKey.user(userId, "encUserKey"))
        try writeString(email,        key: KeychainKey.user(userId, "email"))
        if let name = tokenResp.name {
            try writeString(name,     key: KeychainKey.user(userId, "name"))
        }

        // Persist KDF params for offline unlock.
        let kdfJSON = try JSONEncoder().encode(tokenResp.kdfParams(environment: environment))
        try keychain.write(data: kdfJSON, key: KeychainKey.user(userId, "kdfParams"))

        // Persist server environment for unlock.
        let envJSON = try JSONEncoder().encode(environment)
        try keychain.write(data: envJSON, key: KeychainKey.user(userId, "serverEnvironment"))

        await apiClient.setAccessToken(accessToken)

        return Account(
            userId:            userId,
            email:             email,
            name:              tokenResp.name,
            serverEnvironment: environment
        )
    }

    /// Reconstructs an `Account` from Keychain data for a known `userId`.
    private func account(for userId: String) throws -> Account {
        let email = try readString(key: KeychainKey.user(userId, "email"))
        let name  = try? readString(key: KeychainKey.user(userId, "name"))
        let envData = try keychain.read(key: KeychainKey.user(userId, "serverEnvironment"))

        let env: ServerEnvironment
        do {
            env = try JSONDecoder().decode(ServerEnvironment.self, from: envData)
        } catch {
            logger.error("Server environment decode failed: \(error.localizedDescription, privacy: .public)")
            throw AuthError.invalidCredentials
        }
        return Account(userId: userId, email: email, name: name, serverEnvironment: env)
    }

    /// Returns the persisted device identifier UUID, generating and storing one on first use.
    ///
    /// Per Bitwarden device registration requirements, each installation should present a
    /// stable UUID. Stored under `bw.macos:deviceIdentifier` (not per-user; shared across accounts).
    private func deviceIdentifier() throws -> String {
        do {
            return try readString(key: KeychainKey.deviceIdentifier)
        } catch {
            logger.debug("No device identifier — generating new UUID")
        }
        let newId = UUID().uuidString
        try writeString(newId, key: KeychainKey.deviceIdentifier)
        return newId
    }

    /// Reads a UTF-8 string from the Keychain.
    private func readString(key: String) throws -> String {
        let data = try keychain.read(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        return string
    }

    /// Writes a UTF-8 string to the Keychain.
    private func writeString(_ value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AuthError.invalidCredentials
        }
        try keychain.write(data: data, key: key)
    }

    /// Maps a list of Bitwarden 2FA provider type numbers to a `TwoFactorMethod`.
    ///
    /// Only TOTP (provider 0) is supported in v1.  Any other combination returns `.unsupported`.
    private func twoFactorMethod(from providers: [Int]) -> TwoFactorMethod {
        if providers.contains(0) { return .authenticatorApp }
        let names = providers.map { String($0) }.joined(separator: ", ")
        return .unsupported(name: names)
    }
}

// MARK: - TokenResponse helpers

private extension TokenResponse {
    /// Extracts `KdfParams` from the token response fields.
    func kdfParams(environment _: ServerEnvironment) -> KdfParams {
        let type: KdfType = (kdf == 1) ? .argon2id : .pbkdf2
        return KdfParams(
            type:        type,
            iterations:  kdfIterations ?? 600_000,
            memory:      kdfMemory,
            parallelism: kdfParallelism
        )
    }
}

// MARK: - Keychain key namespacing

/// Centralised Keychain key factory.
///
/// Key format:
///   - Global:    `bw.macos:<name>`
///   - Per-user:  `bw.macos:<userId>:<name>`
enum KeychainKey {
    static let activeUserId    = "bw.macos:activeUserId"
    static let deviceIdentifier = "bw.macos:deviceIdentifier"

    static func user(_ userId: String, _ name: String) -> String {
        "bw.macos:\(userId):\(name)"
    }
}
