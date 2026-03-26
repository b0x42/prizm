import Foundation

/// Orchestrates the full account login flow:
/// validateServerURL → setServerEnvironment → loginWithPassword → (optional) loginWithTOTP → sync.
protocol LoginUseCase {
    func execute(
        serverURL: String,
        email: String,
        masterPassword: Data
    ) async throws -> LoginResult

    func completeTOTP(code: String, rememberDevice: Bool) async throws -> Account

    /// Cancels a pending TOTP challenge and clears in-memory key material held from
    /// the initial password-login step (see `AuthRepository.cancelTwoFactor`).
    func cancelTOTP()
}
