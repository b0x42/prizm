import Foundation

/// Orchestrates the full account login flow:
/// validateServerURL → setServerEnvironment → loginWithPassword → (optional) loginWithTOTP → sync.
protocol LoginUseCase {
    func execute(
        serverURL: String,
        email: String,
        masterPassword: String
    ) async throws -> LoginResult

    func completeTOTP(code: String, rememberDevice: Bool) async throws -> Account
}
