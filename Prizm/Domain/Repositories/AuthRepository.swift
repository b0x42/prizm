import Foundation

/// Manages authentication, session storage, and vault key lifecycle.
/// Implemented by `AuthRepositoryImpl` in the Data layer.
protocol AuthRepository: AnyObject {

    // MARK: - Server configuration

    /// The currently configured server environment, or nil if not yet set.
    var serverEnvironment: ServerEnvironment? { get }

    /// Validates that `urlString` is a well-formed http/https URL.
    /// - Throws: `AuthError.invalidURL` if the URL cannot be parsed or has no host.
    func validateServerURL(_ urlString: String) throws

    /// Persists `environment` and configures the API client base URL.
    func setServerEnvironment(_ environment: ServerEnvironment) async throws

    // MARK: - Login

    /// Performs the full login flow:
    /// 1. POST `/accounts/prelogin` → fetch KDF params.
    /// 2. Derive master key locally (PBKDF2 or Argon2id).
    /// 3. POST `/connect/token` → obtain access + refresh tokens.
    /// 4. Persist tokens + encrypted user key in Keychain.
    ///
    /// - Security goal: `masterPassword` is `Data` so the caller can zero the bytes
    ///   after the call returns, reducing heap exposure (Constitution §III).
    /// - Returns: `.success(Account)` or `.requiresTwoFactor(method:)`.
    /// - Throws: `AuthError` on network or credential failure.
    func loginWithPassword(email: String, masterPassword: Data) async throws -> LoginResult

    /// Completes a pending TOTP two-factor challenge.
    /// - Parameters:
    ///   - code: The 6-digit TOTP code from the user's authenticator app.
    ///   - rememberDevice: When true, the server suppresses future 2FA prompts for this device.
    /// - Returns: The authenticated `Account`.
    /// - Throws: `AuthError.invalidTwoFactorCode` on wrong code.
    func loginWithTOTP(code: String, rememberDevice: Bool) async throws -> Account

    /// Cancels a pending TOTP challenge and discards the in-memory `PendingTwoFactor`
    /// state (stretched keys + password hash) held from the initial password login step.
    ///
    /// - Security goal: without this call the derived key material lives in memory until
    ///   the next login attempt or app restart (Constitution §III). Call this whenever the
    ///   user dismisses the TOTP prompt without submitting a code.
    func cancelTwoFactor()

    // MARK: - Unlock

    /// Re-derives the symmetric key from `masterPassword` using stored KDF params.
    /// No network request is made — purely local crypto.
    ///
    /// - Security goal: `masterPassword` is `Data` so the caller can zero the bytes
    ///   after the call returns (Constitution §III).
    /// - Returns: The unlocked `Account`.
    /// - Throws: `AuthError.invalidCredentials` on wrong password.
    func unlockWithPassword(_ masterPassword: Data) async throws -> Account

    // MARK: - Session

    /// Returns the stored `Account` from Keychain, or nil if no session exists.
    func storedAccount() -> Account?

    /// Clears all per-user Keychain keys and resets in-memory state.
    /// Called on explicit sign-out. Triggers transition to blank `LoginView`.
    func signOut() async throws

    // MARK: - Lock

    /// Releases decrypted key material from `PrizmCryptoServiceImpl`.
    /// Does NOT clear Keychain tokens — session survives lock/unlock.
    func lockVault() async

    // MARK: - Biometric unlock

    /// Whether biometric unlock is available (enabled in preferences AND device supports biometrics).
    /// Fast synchronous check suitable for UI binding — does NOT read the Keychain.
    var biometricUnlockAvailable: Bool { get }

    /// Stores the current vault symmetric key in a biometric-protected Keychain item.
    /// Requires the vault to be unlocked (keys in memory).
    /// - Throws: `AuthError.biometricUnavailable` if the vault is locked.
    func enableBiometricUnlock() async throws

    /// Deletes the biometric Keychain item and clears the preference.
    func disableBiometricUnlock() async throws

    /// Reads the vault key from the biometric Keychain item and unlocks the vault.
    /// - Returns: The unlocked `Account`.
    /// - Throws: `AuthError.biometricInvalidated` if biometric enrollment changed.
    func unlockWithBiometrics() async throws -> Account
}

// MARK: - Supporting types

nonisolated enum LoginResult {
    case success(Account)
    case requiresTwoFactor(TwoFactorMethod)
}

/// Two-factor methods supported in v1. Only `authenticatorApp` (TOTP) is handled;
/// all others surface as `unsupported` with the method name for a clear error message.
nonisolated enum TwoFactorMethod {
    case authenticatorApp
    case unsupported(name: String)
}

nonisolated enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case invalidTwoFactorCode
    case invalidURL
    case serverUnreachable
    case unrecognizedServer
    case networkUnavailable
    case unsupported2FAMethod(String)
    /// Biometric Keychain item was invalidated due to fingerprint enrollment change.
    case biometricInvalidated
    /// Biometric unlock cannot be enabled — vault is locked (keys not in memory).
    case biometricUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or master password. Check your email and master password."
        case .invalidTwoFactorCode:
            return "Invalid two-factor code. Please try again."
        case .invalidURL:
            return "Invalid server URL. Make sure to include https://."
        case .serverUnreachable:
            return "Cannot reach the server. Verify the URL and check your connection."
        case .unrecognizedServer:
            return "This server doesn't appear to be a Bitwarden instance."
        case .networkUnavailable:
            return "No internet connection. Check your network connection."
        case .unsupported2FAMethod(let name):
            return "Two-factor method '\(name)' is not supported. Use an authenticator app."
        case .biometricInvalidated:
            return "Your Touch ID settings have changed. Please enter your master password to continue."
        case .biometricUnavailable:
            return "Biometric unlock is not available. Please unlock with your master password."
        }
    }
}
