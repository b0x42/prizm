import Foundation
import os.log

// MARK: - UnlockUseCaseImpl

/// Orchestrates the vault unlock flow (User Story 2):
///   1. Call `AuthRepository.unlockWithPassword` — purely local KDF, no network.
///   2. Return the `Account` immediately — background sync is triggered by `UnlockViewModel`
///      via `SyncService.trigger()` after the auth flow transitions to `.vault`.
///
/// On wrong password: `AuthError.invalidCredentials` is thrown and the vault stays locked.
/// `lockVault` is intentionally NOT called on failure — the existing locked session is
/// preserved so the user can retry without re-entering their server URL or re-authenticating.
final class UnlockUseCaseImpl: UnlockUseCase {

    private let auth: any AuthRepository

    private let logger = Logger(subsystem: "com.macwarden", category: "UnlockUseCase")

    init(auth: any AuthRepository) {
        self.auth = auth
    }

    func execute(masterPassword: Data) async throws -> Account {
        logger.info("Attempting vault unlock")
        let account = try await auth.unlockWithPassword(masterPassword)
        logger.info("Unlock succeeded — background sync will be triggered by UnlockViewModel")
        return account
    }
}
