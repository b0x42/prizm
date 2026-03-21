import Foundation
import os.log

// MARK: - UnlockUseCaseImpl

/// Orchestrates the vault unlock flow (User Story 2):
///   1. Call `AuthRepository.unlockWithPassword` — purely local KDF, no network.
///   2. On success, call `SyncRepository.sync` to re-populate the in-memory vault
///      (the in-memory store is cleared on every app quit).
///
/// On wrong password: `AuthError.invalidCredentials` is thrown.
/// `lockVault` is NOT called on failure — the existing session stays intact (FR-039).
final class UnlockUseCaseImpl: UnlockUseCase {

    private let auth: any AuthRepository
    private let sync: any SyncRepository

    private let logger = Logger(subsystem: "com.macwarden", category: "UnlockUseCase")

    init(auth: any AuthRepository, sync: any SyncRepository) {
        self.auth = auth
        self.sync = sync
    }

    func execute(masterPassword: String) async throws -> Account {
        // Step 1: Derive master key locally and unlock the crypto service.
        logger.info("Attempting vault unlock")
        let account = try await auth.unlockWithPassword(masterPassword)

        // Step 2: Re-sync vault — in-memory store is empty after every app launch.
        logger.info("Unlock succeeded — re-syncing vault for \(account.userId, privacy: .private)")
        _ = try await sync.sync(progress: { _ in })

        return account
    }
}
