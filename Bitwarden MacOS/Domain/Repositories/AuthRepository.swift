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
    /// - Returns: `.success(Account)` or `.requiresTwoFactor(method:)`.
    /// - Throws: `AuthError` on network or credential failure.
    func loginWithPassword(email: String, masterPassword: String) async throws -> LoginResult

    /// Completes a pending TOTP two-factor challenge.
    /// - Parameters:
    ///   - code: The 6-digit TOTP code from the user's authenticator app.
    ///   - rememberDevice: When true, the server suppresses future 2FA prompts for this device.
    /// - Returns: The authenticated `Account`.
    /// - Throws: `AuthError.invalidTwoFactorCode` on wrong code.
    func loginWithTOTP(code: String, rememberDevice: Bool) async throws -> Account

    // MARK: - Unlock

    /// Re-derives the symmetric key from `masterPassword` using stored KDF params.
    /// No network request is made — purely local crypto.
    /// - Returns: The unlocked `Account`.
    /// - Throws: `AuthError.invalidCredentials` on wrong password.
    func unlockWithPassword(_ masterPassword: String) async throws -> Account

    // MARK: - Session

    /// Returns the stored `Account` from Keychain, or nil if no session exists.
    func storedAccount() -> Account?

    /// Clears all per-user Keychain keys and resets in-memory state.
    /// Called on explicit sign-out. Triggers transition to blank `LoginView`.
    func signOut() async throws

    // MARK: - Lock

    /// Releases decrypted key material from `BitwardenCryptoServiceImpl`.
    /// Does NOT clear Keychain tokens — session survives lock/unlock.
    func lockVault() async
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

nonisolated enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case invalidTwoFactorCode
    case invalidURL
    case serverUnreachable
    case unrecognizedServer
    case networkUnavailable
    case unsupported2FAMethod(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or master password."
        case .invalidTwoFactorCode:
            return "Invalid two-factor code. Please try again."
        case .invalidURL:
            return "Invalid server URL. Please enter a full URL including https://."
        case .serverUnreachable:
            return "Cannot reach the server. Check the URL and your connection."
        case .unrecognizedServer:
            return "This server doesn't appear to be a Bitwarden instance."
        case .networkUnavailable:
            return "No internet connection."
        case .unsupported2FAMethod(let name):
            return "Two-factor method '\(name)' is not supported. Use an authenticator app."
        }
    }
}
