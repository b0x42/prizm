import Foundation
import os.log

// MARK: - LoginUseCaseImpl

/// Orchestrates the full account login flow:
///   1. Validate + set server URL.
///   2. Call `AuthRepository.loginWithPassword`.
///   3. If `.success`: call `SyncRepository.sync` to populate the vault.
///   4. If `.requiresTwoFactor`: return immediately — sync is deferred to after TOTP.
///
/// `SyncRepository.sync` is called here (not inside `AuthRepository`) to keep the
/// Domain layer orchestration visible and testable at the use-case level.
final class LoginUseCaseImpl: LoginUseCase {

    private let auth: any AuthRepository
    private let sync: any SyncRepository

    private let logger = Logger(subsystem: "com.bitwarden-macos", category: "LoginUseCase")

    init(auth: any AuthRepository, sync: any SyncRepository) {
        self.auth = auth
        self.sync = sync
    }

    func execute(serverURL: String, email: String, masterPassword: String) async throws -> LoginResult {
        // Step 1: Validate URL (throws AuthError.invalidURL on failure).
        try auth.validateServerURL(serverURL)

        // Step 2: Configure server environment.
        let trimmed = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        guard let url = URL(string: trimmed) else { throw AuthError.invalidURL }
        let environment = ServerEnvironment(base: url, overrides: nil)
        try await auth.setServerEnvironment(environment)

        // Step 3: Attempt password login.
        logger.info("Attempting login for \(email, privacy: .private)")
        let result = try await auth.loginWithPassword(email: email, masterPassword: masterPassword)

        switch result {
        case .success:
            // Step 4: Sync vault immediately after successful login.
            // Sync failure is non-fatal — show vault with whatever was synced (FR-049).
            logger.info("Login succeeded — starting vault sync")
            do {
                _ = try await sync.sync(progress: { _ in })
            } catch {
                logger.error("Post-login sync failed (non-fatal): \(error.localizedDescription, privacy: .public)")
            }
            return result

        case .requiresTwoFactor:
            // 2FA required — sync deferred; caller must invoke completeTOTP then re-sync.
            logger.info("Login requires 2FA")
            return result
        }
    }

    func completeTOTP(code: String, rememberDevice: Bool) async throws -> Account {
        logger.info("Completing TOTP")
        let account = try await auth.loginWithTOTP(code: code, rememberDevice: rememberDevice)
        // Sync failure is non-fatal — show vault with whatever was synced (FR-049).
        do {
            _ = try await sync.sync(progress: { _ in })
        } catch {
            logger.error("Post-TOTP sync failed (non-fatal): \(error.localizedDescription, privacy: .public)")
        }
        return account
    }
}
