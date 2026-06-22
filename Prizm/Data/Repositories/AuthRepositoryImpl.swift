import Foundation
import LocalAuthentication
import os.log

// MARK: - AuthRepositoryImpl

/// Concrete implementation of `AuthRepository`.
///
/// Orchestrates the full Bitwarden login flow:
///   1. POST `/accounts/prelogin` → KDF params
///   2. Derive master key (PBKDF2 or Argon2id) locally
///   3. POST `/connect/token` → access + refresh tokens
///   4. Decrypt encUserKey → vault symmetric keys
///   5. Unlock `PrizmCryptoServiceImpl` with vault keys
///   6. Persist tokens + metadata in Keychain
///
/// Two-factor flow: `loginWithPassword` returns `.requiresTwoFactor` and stores
/// pending state in-memory; `loginWithTOTP` completes the challenge.
///
/// Thread safety: all mutable state is read/written on the calling actor.
/// `@MainActor` annotation ensures single-threaded access during tests and UI.
@MainActor
final class AuthRepositoryImpl: AuthRepository, EmbeddedBiometricUnlock {

    // MARK: - Dependencies

    private let apiClient:  any PrizmAPIClientProtocol
    private let crypto:     any PrizmCryptoService
    private let keychain:   any KeychainService
    private let biometricKeychain: any BiometricKeychainService

    private let logger = Logger(subsystem: "com.prizm", category: "AuthRepository")

    // MARK: - Server configuration

    private(set) var serverEnvironment: ServerEnvironment?

    // MARK: - Pending 2FA state
    // Set by loginWithPassword when the server requests 2FA; consumed by loginWithTOTP.

    private struct PendingTwoFactor {
        let email:         String
        let passwordHash:  String
        let kdfParams:     KdfParams
        // `var` so cancelTwoFactor() can zero the key buffers before releasing the struct
        // (Constitution §III). Swift ARC does not guarantee immediate deallocation on nil.
        var stretchedKeys: CryptoKeys
        let deviceId:      String
    }
    private var pendingTwoFactor: PendingTwoFactor?

    // MARK: - Pending new-device OTP state
    // Set by loginWithPassword when the server returns device_error; consumed by loginWithNewDeviceOTP.

    private struct PendingNewDeviceOTP {
        let email:        String
        let passwordHash: String
        // `var` so cancelNewDeviceOTP() can zero key buffers in-place (Constitution §III).
        var stretchedKeys: CryptoKeys
        let deviceId:     String
        let environment:  ServerEnvironment
    }
    private var pendingNewDeviceOTP: PendingNewDeviceOTP?

    // MARK: - Init

    private let clientIdentifier: String

    init(
        apiClient:         any PrizmAPIClientProtocol,
        crypto:            any PrizmCryptoService,
        keychain:          any KeychainService,
        biometricKeychain: any BiometricKeychainService,
        clientIdentifier:  String = Config.bitwardenClientIdentifier
    ) {
        self.apiClient        = apiClient
        self.crypto           = crypto
        self.keychain         = keychain
        self.biometricKeychain = biometricKeychain
        self.clientIdentifier  = clientIdentifier
    }

    // MARK: - Server configuration

    func validateServerURL(_ urlString: String) throws {
        // Strip trailing slash for normalisation.
        let trimmed = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
        // Only HTTPS is permitted — Constitution §III requires all vault communication
        // to use TLS. Allowing http:// would expose the master password hash and tokens
        // to network interception even on "trusted" local networks.
        guard let url = URL(string: trimmed),
              url.scheme == "https",
              url.host != nil else {
            logger.error("URL validation failed: \(urlString, privacy: .public)")
            throw AuthError.invalidURL
        }
    }

    func setServerEnvironment(_ environment: ServerEnvironment) async throws {
        serverEnvironment = environment
        await apiClient.setServerEnvironment(environment)
        logger.info("Server environment set: \(environment.serverType.rawValue, privacy: .public)")
    }

    // MARK: - Login

    func loginWithPassword(email: String, masterPassword: Data) async throws -> LoginResult {
        logger.info("Login attempt for \(email, privacy: .private)")
        guard let env = serverEnvironment else {
            throw AuthError.serverUnreachable
        }
        // Cloud environments require a registered client identifier (ADR-0023).
        // Self-hosted Vaultwarden does not enforce this check.
        if env.serverType != .selfHosted && clientIdentifier.isEmpty {
            logger.error("Cloud login blocked: bitwardenClientIdentifier not configured")
            throw AuthError.clientIdentifierNotConfigured
        }

        // Step 1: Fetch KDF params.
        logger.info("Step 1: fetching KDF params for \(email, privacy: .private)")
        let preLogin   = try await apiClient.preLogin(email: email)
        let kdfParams  = preLogin.kdfParams
        if DebugConfig.isEnabled {
            logger.debug("[debug] KDF params → type=\(String(describing: kdfParams.type), privacy: .public) iterations=\(kdfParams.iterations, privacy: .public) memory=\(kdfParams.memory.map(String.init) ?? "nil", privacy: .public) parallelism=\(kdfParams.parallelism.map(String.init) ?? "nil", privacy: .public)")
        }

        // Step 2: Derive master key locally — never sent to server.
        // `masterPassword` is `Data` (typed to allow zeroing; `String` cannot be zeroed).
        // Swift CoW prevents in-place zeroing of a value-type parameter without unsafe code;
        // the local copy is released on return. Accepted limitation — tracked as §III known gap.
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
        // Per Bitwarden Security Whitepaper §4 + RFC 8018 §5.2 (PBKDF2):
        // A second PBKDF2 round is applied over the masterKey using the plaintext
        // password as input, producing a value the server can verify without storing —
        // or ever receiving — the raw master key. The master key never leaves the device.
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
                twoFactorRemember: false,
                newDeviceOTP:      nil
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
            case .newDeviceNotVerified:
                // Cloud: server doesn't recognise this device; an OTP was dispatched to the user's email.
                // Self-hosted: this response is unexpected — surface as invalid credentials.
                if env.serverType != .selfHosted {
                    pendingNewDeviceOTP = PendingNewDeviceOTP(
                        email:        email,
                        passwordHash: serverHash,
                        stretchedKeys: stretched,
                        deviceId:     deviceId,
                        environment:  env
                    )
                    logger.info("New-device OTP required — pending OTP stored")
                    return .requiresNewDeviceOTP
                } else {
                    logger.error("Unexpected device_error from self-hosted server")
                    throw AuthError.invalidCredentials
                }
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
                twoFactorRemember: rememberDevice,
                newDeviceOTP:      nil
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
            case .newDeviceNotVerified:
                logger.error("Unexpected device_error during TOTP flow")
                throw AuthError.invalidCredentials
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

    func cancelTwoFactor() {
        // Explicitly zero the stretched key buffers before releasing the struct.
        // Setting pendingTwoFactor = nil alone does not guarantee immediate deallocation —
        // ARC may defer it. Zeroing the Data buffers in-place reduces the window during
        // which derived key material lives in the heap (Constitution §III).
        // Note: passwordHash (String) cannot be zeroed — String storage is immutable.
        // `pendingTwoFactor!` is used for the mutations rather than the local `pending`
        // copy produced by `if let` — zeroing `pending` would only zero the copy's CoW
        // buffer, not the stored struct's. In-place mutation through `pendingTwoFactor!`
        // is safe here because we verified non-nil one line above.
        if let pending = pendingTwoFactor {
            pendingTwoFactor!.stretchedKeys.encryptionKey.resetBytes(
                in: 0..<pending.stretchedKeys.encryptionKey.count
            )
            pendingTwoFactor!.stretchedKeys.macKey.resetBytes(
                in: 0..<pending.stretchedKeys.macKey.count
            )
        }
        pendingTwoFactor = nil
        logger.info("Pending 2FA state cleared — stretched keys zeroed")
    }

    func loginWithNewDeviceOTP(_ otp: String) async throws -> Account {
        logger.info("Submitting new-device OTP")
        guard let pending = pendingNewDeviceOTP else {
            throw AuthError.otpSessionExpired
        }
        let tokenResp: TokenResponse
        do {
            tokenResp = try await apiClient.identityToken(
                email:             pending.email,
                passwordHash:      pending.passwordHash,
                deviceIdentifier:  pending.deviceId,
                twoFactorToken:    nil,
                twoFactorProvider: nil,
                twoFactorRemember: false,
                newDeviceOTP:      otp
            )
        } catch {
            logger.error("New-device OTP rejected: \(error.localizedDescription, privacy: .public)")
            // Preserve pendingNewDeviceOTP so the user can correct the code and retry.
            throw error
        }
        // OTP accepted: zero key material before clearing pending state (Constitution §III).
        let encCount = pendingNewDeviceOTP!.stretchedKeys.encryptionKey.count
        let macCount = pendingNewDeviceOTP!.stretchedKeys.macKey.count
        pendingNewDeviceOTP!.stretchedKeys.encryptionKey.resetBytes(in: 0..<encCount)
        pendingNewDeviceOTP!.stretchedKeys.macKey.resetBytes(in: 0..<macCount)
        pendingNewDeviceOTP = nil
        logger.info("New-device OTP accepted")
        return try await finalizeSession(
            tokenResp:   tokenResp,
            stretched:   pending.stretchedKeys,
            environment: pending.environment
        )
    }

    func requestNewDeviceOTP() async throws {
        logger.info("Requesting new OTP dispatch")
        guard let pending = pendingNewDeviceOTP else {
            throw AuthError.otpSessionExpired
        }
        do {
            // Re-posting without newdeviceotp causes the server to dispatch a new OTP email
            // and respond with HTTP 400 + device_error again. That "error" is the server's
            // confirmation that the email was sent — catching it here is intentional.
            // Do NOT remove this catch: it converts the expected error into a success path.
            _ = try await apiClient.identityToken(
                email:             pending.email,
                passwordHash:      pending.passwordHash,
                deviceIdentifier:  pending.deviceId,
                twoFactorToken:    nil,
                twoFactorProvider: nil,
                twoFactorRemember: false,
                newDeviceOTP:      nil
            )
        } catch IdentityTokenError.newDeviceNotVerified {
            // Expected: server sent a new OTP email and returned device_error as confirmation.
            logger.info("New OTP dispatched (device_error treated as success)")
            return
        }
        // Unexpected: server returned a token response instead of device_error.
        // The device may have been verified by another client while this challenge was open.
        // Pending state is preserved — caller can still submit OTP or cancel.
        logger.warning("requestNewDeviceOTP: unexpected token success — device may have already been verified")
    }

    func cancelNewDeviceOTP() {
        // Explicitly zero the stretched key buffers before releasing the struct.
        // Setting pendingNewDeviceOTP = nil alone does not guarantee immediate deallocation —
        // ARC may defer it. Zeroing the Data buffers in-place reduces the window during
        // which derived key material lives in the heap (Constitution §III).
        // Note: passwordHash (String) cannot be zeroed — String storage is immutable.
        // This is an accepted limitation shared with the TOTP flow (cancelTwoFactor).
        if let pending = pendingNewDeviceOTP {
            pendingNewDeviceOTP!.stretchedKeys.encryptionKey.resetBytes(
                in: 0..<pending.stretchedKeys.encryptionKey.count
            )
            pendingNewDeviceOTP!.stretchedKeys.macKey.resetBytes(
                in: 0..<pending.stretchedKeys.macKey.count
            )
        }
        pendingNewDeviceOTP = nil
        logger.info("Pending new-device OTP state cleared — stretched keys zeroed")
    }

    func unlockWithPassword(_ masterPassword: Data) async throws -> Account {
        logger.info("Unlock attempt")
        let userId: String
        do {
            userId = try readString(key: KeychainKey.activeUserId)
        } catch {
            logger.error("No active user ID in Keychain: \(error.localizedDescription, privacy: .public)")
            throw AuthError.invalidCredentials
        }

        // Read account data (email, name, serverEnvironment) once via account(for:).
        // Previously email was also read directly below for use in makeMasterKey, producing
        // a duplicate read. Now account(for:) is called first and email is reused from it.
        let restoredAccount: Account
        do {
            restoredAccount = try account(for: userId)
        } catch {
            logger.error("Missing session data in Keychain: \(error.localizedDescription, privacy: .public)")
            throw AuthError.invalidCredentials
        }

        let kdfKey    = KeychainKey.user(userId, "kdfParams")
        let encKeyKey = KeychainKey.user(userId, "encUserKey")

        let kdfJSON: String
        let encUserKey: String
        do {
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
        // `masterPassword` is already `Data`; pass directly to KDF (Constitution §III).
        let masterKey  = try await crypto.makeMasterKey(
            password: masterPassword,
            email:    restoredAccount.email.lowercased(),
            kdf:      kdfParams
        )
        let stretched  = try await crypto.stretchKey(masterKey: masterKey)
        let vaultKeys  = try await crypto.decryptSymmetricKey(
            encUserKey:    encUserKey,
            stretchedKeys: stretched
        )
        await crypto.unlockWith(keys: vaultKeys)

        // Restore API client state so the post-unlock sync can make authenticated requests.
        // Both baseURL and accessToken are nil on a fresh app launch until restored here.
        serverEnvironment = restoredAccount.serverEnvironment
        await apiClient.setServerEnvironment(restoredAccount.serverEnvironment)

        if let accessToken = try? readString(key: KeychainKey.user(userId, "accessToken")) {
            await apiClient.setAccessToken(accessToken)
            if DebugConfig.isEnabled {
                logger.debug("[debug] unlock: baseURL and access token restored to API client")
            }

            // The stored access token may be expired. Attempt a refresh using the stored
            // refresh token so the post-unlock sync doesn't fail with 401.
            let refreshTokenOpt = try? readString(key: KeychainKey.user(userId, "refreshToken"))
            if refreshTokenOpt == nil {
                logger.debug("Unlock: no refresh token in Keychain — skipping token refresh")
            }
            if let refreshToken = refreshTokenOpt {
                do {
                    let tokens = try await apiClient.refreshAccessToken(refreshToken: refreshToken)
                    do {
                        try writeString(tokens.accessToken, key: KeychainKey.user(userId, "accessToken"))
                        if let newRefresh = tokens.refreshToken {
                            try writeString(newRefresh, key: KeychainKey.user(userId, "refreshToken"))
                        }
                    } catch {
                        // Persisting the refreshed token failed — the next launch will use
                        // the old (expired) token and the user may be signed out unexpectedly.
                        logger.error("Unlock: failed to persist refreshed tokens — next launch may require re-auth: \(error.localizedDescription, privacy: .public)")
                    }
                    if DebugConfig.isEnabled {
                        logger.debug("[debug] unlock: access token refreshed successfully")
                    }
                } catch {
                    // Refresh failed — keep the old token; sync will fail with 401 (non-fatal).
                    logger.warning("Unlock: token refresh failed — sync may fail: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else {
            logger.error("Unlock: access token not found in Keychain — sync will fail with 401")
        }

        logger.info("Unlock succeeded")
        return restoredAccount
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

        // Clear biometric Keychain item and preference before clearing other keys.
        try? await disableBiometricUnlock()

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

        // Use self.lockVault() rather than crypto.lockVault() directly so that the
        // .vaultDidLock notification is posted — ItemEditViewModel observes it to
        // dismiss any open edit sheet and clear the plaintext DraftVaultItem (§III).
        await lockVault()

        // Clear the bearer token from the API client's memory so it cannot be read
        // from a heap dump after sign-out (Constitution §III).
        await apiClient.clearAccessToken()

        serverEnvironment   = nil
        pendingTwoFactor    = nil
        pendingNewDeviceOTP = nil
    }

    // MARK: - Lock

    func lockVault() async {
        await crypto.lockVault()
        // Notify any open edit sheets to dismiss immediately (no confirmation prompt).
        // Posted on the main queue because subscribers are @MainActor UI components.
        await MainActor.run {
            NotificationCenter.default.post(name: .vaultDidLock, object: nil)
        }
    }

    // MARK: - Biometric unlock

    var deviceBiometricCapable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricUnlockAvailable: Bool {
        // Fast synchronous check for UI binding (design Decision 5).
        // Actual Keychain item existence is verified only inside unlockWithBiometrics().
        UserDefaults.standard.bool(forKey: "biometricUnlockEnabled")
            && LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func enableBiometricUnlock() async throws {
        // Guard: vault must be unlocked — keys must be in memory (spec requirement).
        guard await crypto.isUnlocked else {
            throw AuthError.biometricUnavailable
        }
        let keys = try await crypto.currentKeys()
        let data = keys.toData()
        guard let userId = try? readString(key: KeychainKey.activeUserId) else {
            throw AuthError.biometricUnavailable
        }
        try biometricKeychain.writeBiometric(
            data: data,
            key: KeychainKey.biometricVaultKey(userId)
        )
        UserDefaults.standard.set(true, forKey: "biometricUnlockEnabled")
        logger.info("Biometric unlock enabled")
    }

    func disableBiometricUnlock() async throws {
        if let userId = try? readString(key: KeychainKey.activeUserId) {
            try? biometricKeychain.deleteBiometric(key: KeychainKey.biometricVaultKey(userId))
        }
        UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
        logger.info("Biometric unlock disabled")
    }

    func unlockWithBiometrics() async throws -> Account {
        logger.info("Biometric unlock attempt")
        guard let userId = try? readString(key: KeychainKey.activeUserId) else {
            throw AuthError.biometricUnavailable
        }

        let restoredAccount: Account
        do {
            restoredAccount = try account(for: userId)
        } catch {
            logger.error("Missing session data for biometric unlock: \(error.localizedDescription, privacy: .public)")
            throw AuthError.biometricUnavailable
        }

        // Read the biometric Keychain item — evaluatePolicy runs inside readBiometric,
        // producing the inline Touch ID prompt (no security-agent modal).
        let keyData: Data
        do {
            keyData = try await biometricKeychain.readBiometric(
                key: KeychainKey.biometricVaultKey(userId)
            )
        } catch let error as KeychainError where error == .itemNotFound {
            // Keychain item deleted externally (Keychain Access, reinstall, etc.) —
            // NOT a fingerprint-change. Degrade silently: clear the flag and reset
            // the enrollment gate so re-enrollment is offered after next password unlock.
            // UnlockViewModel must NOT show an error for this case (spec §degradation).
            UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
            UserDefaults.standard.set(false, forKey: "biometricEnrollmentPromptShown")
            throw AuthError.biometricItemNotFound
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .systemCancel, .appCancel:
                // User cancelled — rethrow as errSecUserCanceled so UnlockViewModel re-arms.
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecUserCanceled))
            default:
                // Lockout or other LAError — surface error without clearing stored key.
                throw laError
            }
        } catch {
            // Legacy OSStatus errors from SecItemCopyMatching (e.g. .biometryCurrentSet
            // invalidation that surfaces as errSecAuthFailed on some OS versions).
            let nsError = error as NSError
            if nsError.domain == NSOSStatusErrorDomain {
                let status = OSStatus(nsError.code)
                if status == errSecUserCanceled || status == errSecAuthFailed {
                    throw error
                }
            }
            UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
            UserDefaults.standard.set(false, forKey: "biometricEnrollmentPromptShown")
            throw AuthError.biometricInvalidated
        }

        // Deserialize CryptoKeys from the 64-byte blob (design Decision 1).
        guard let vaultKeys = CryptoKeys(data: keyData) else {
            logger.error("Biometric Keychain item has invalid format")
            throw AuthError.biometricUnavailable
        }

        await crypto.unlockWith(keys: vaultKeys)

        // Restore API client state — same as unlockWithPassword().
        serverEnvironment = restoredAccount.serverEnvironment
        await apiClient.setServerEnvironment(restoredAccount.serverEnvironment)

        if let accessToken = try? readString(key: KeychainKey.user(userId, "accessToken")) {
            await apiClient.setAccessToken(accessToken)

            if let refreshToken = try? readString(key: KeychainKey.user(userId, "refreshToken")) {
                do {
                    let tokens = try await apiClient.refreshAccessToken(refreshToken: refreshToken)
                    try? writeString(tokens.accessToken, key: KeychainKey.user(userId, "accessToken"))
                    if let newRefresh = tokens.refreshToken {
                        try? writeString(newRefresh, key: KeychainKey.user(userId, "refreshToken"))
                    }
                } catch {
                    logger.warning("Biometric unlock: token refresh failed — sync may fail: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        logger.info("Biometric unlock succeeded")
        return restoredAccount
    }

    // MARK: - EmbeddedBiometricUnlock

    /// Evaluates biometric policy on `context` then reads the vault key and unlocks.
    /// If `LAAuthenticationView` was paired with `context` before this call (via
    /// `EmbeddedTouchIDView`), `evaluatePolicy` routes inline — no modal appears.
    func unlockWithBiometrics(context: LAContext) async throws -> Account {
        logger.info("Embedded biometric unlock attempt")
        guard let userId = try? readString(key: KeychainKey.activeUserId) else {
            throw AuthError.biometricUnavailable
        }

        let restoredAccount: Account
        do {
            restoredAccount = try account(for: userId)
        } catch {
            logger.error("Missing session data for embedded biometric unlock: \(error.localizedDescription, privacy: .public)")
            throw AuthError.biometricUnavailable
        }

        // readBiometric(key:context:) calls evaluatePolicy on the provided context.
        // Because LAAuthenticationView is paired with it, no modal appears.
        let keyData: Data
        do {
            keyData = try await biometricKeychain.readBiometric(
                key: KeychainKey.biometricVaultKey(userId),
                context: context
            )
        } catch let error as KeychainError where error == .itemNotFound {
            // Same silent-degradation path as the non-embedded overload above.
            UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
            UserDefaults.standard.set(false, forKey: "biometricEnrollmentPromptShown")
            throw AuthError.biometricItemNotFound
        } catch {
            // Let LAError (cancel, lockout) propagate — caller handles re-arming.
            throw error
        }

        guard let vaultKeys = CryptoKeys(data: keyData) else {
            logger.error("Embedded biometric Keychain item has invalid format")
            throw AuthError.biometricUnavailable
        }

        await crypto.unlockWith(keys: vaultKeys)
        serverEnvironment = restoredAccount.serverEnvironment
        await apiClient.setServerEnvironment(restoredAccount.serverEnvironment)

        if let accessToken = try? readString(key: KeychainKey.user(userId, "accessToken")) {
            await apiClient.setAccessToken(accessToken)
            if let refreshToken = try? readString(key: KeychainKey.user(userId, "refreshToken")) {
                do {
                    let tokens = try await apiClient.refreshAccessToken(refreshToken: refreshToken)
                    try? writeString(tokens.accessToken, key: KeychainKey.user(userId, "accessToken"))
                    if let newRefresh = tokens.refreshToken {
                        try? writeString(newRefresh, key: KeychainKey.user(userId, "refreshToken"))
                    }
                } catch {
                    logger.warning("Embedded biometric: token refresh failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        logger.info("Embedded biometric unlock succeeded")
        return restoredAccount
    }

    // MARK: - Private helpers

    /// Completes a successful token exchange: decrypts vault key, stores credentials, returns Account.
    private func finalizeSession(
        tokenResp:   TokenResponse,
        stretched:   CryptoKeys,
        environment: ServerEnvironment
    ) async throws -> Account {
        // Vaultwarden omits UserId/Email from the token response body (unlike the official
        // Bitwarden server, which includes them as PascalCase fields). Extract identity from
        // JWT claims instead: sub → userId, email → email, name → display name.
        // Trust model: the JWT was just issued by the user's own configured server over HTTPS
        // and is only used to read their own identity — not to make authorization decisions.
        // A malicious server could falsify these claims, but trusting the chosen server is
        // an explicit prerequisite of self-hosting. Signature verification is skipped for
        // this reason — see decodeJWTClaims for the full rationale.
        let jwtClaims = decodeJWTClaims(tokenResp.accessToken)
        let userId = tokenResp.userId ?? jwtClaims["sub"] as? String
        let email  = tokenResp.email  ?? jwtClaims["email"] as? String
        let name   = tokenResp.name   ?? jwtClaims["name"] as? String

        if DebugConfig.isEnabled {
            let jwtKeys = jwtClaims.keys.sorted().joined(separator: ", ")
            logger.debug("[debug] finalizeSession: body userId=\(tokenResp.userId != nil, privacy: .public) email=\(tokenResp.email != nil, privacy: .public) | JWT claims: [\(jwtKeys, privacy: .public)] | resolved userId=\(userId != nil, privacy: .public) email=\(email != nil, privacy: .public)")
        }

        guard let userId,
              let email,
              let encKey       = tokenResp.key,
              let accessToken  = tokenResp.accessToken.isEmpty ? nil : tokenResp.accessToken,
              let refreshToken = tokenResp.refreshToken else {
            logger.error("finalizeSession: missing required fields — userId=\(userId != nil, privacy: .public) email=\(email != nil, privacy: .public) key=\(tokenResp.key != nil, privacy: .public) accessTokenNonEmpty=\(!tokenResp.accessToken.isEmpty, privacy: .public) refreshToken=\(tokenResp.refreshToken != nil, privacy: .public)")
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
        if let name {
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
            name:              name,
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

    /// Decodes the payload of a JWT access token without verifying the signature.
    ///
    /// Vaultwarden does not return `UserId` or `Email` in the token response body —
    /// they are present as standard JWT claims (`sub` = userId, `email` = email, `name` = name).
    ///
    /// - Security goal: extract the user's own identity fields from a freshly-issued token.
    /// - Why signature skip is safe: the token arrived over HTTPS from our configured server
    ///   moments ago and is only used to read `sub`/`email`/`name` for local Keychain storage.
    ///   It is never used for access-control or authorization decisions.
    /// - What this does NOT protect against: a compromised or malicious self-hosted server.
    ///   If the server issues a JWT with a falsified `sub`, we would store the wrong userId.
    ///   Defending against a malicious server is out of scope — the user chose to trust it.
    /// - Base64url decoding per RFC 7519 §3 (JWT compact serialization: header.payload.signature).
    ///
    /// - Parameter jwt: A dot-separated JWT string (`header.payload.signature`).
    /// - Returns: Decoded payload as a `[String: Any]` dictionary, or empty on failure.
    private func decodeJWTClaims(_ jwt: String) -> [String: Any] {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return [:] }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Add padding if needed (JWT uses unpadded base64url).
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to decode JWT payload")
            return [:]
        }
        return json
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

    /// Per-user biometric vault key — stored via `BiometricKeychainServiceImpl`
    /// behind `.biometryCurrentSet` access control (design Decision 1).
    static func biometricVaultKey(_ userId: String) -> String {
        "bw.macos:\(userId):biometricVaultKey"
    }
}
