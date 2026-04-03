import Foundation
@testable import Prizm

/// Test double for `SyncRepository` — used by `LoginUseCaseTests`.
actor MockSyncRepository: SyncRepository {

    // MARK: - State observations
    // nonisolated(unsafe) allows tests to read/write without await — safe in single-threaded tests.

    nonisolated(unsafe) var syncCalled: Bool = false
    nonisolated(unsafe) var progressMessages: [String] = []

    // MARK: - Stubs

    nonisolated(unsafe) var stubbedSyncResult: SyncResult = SyncResult(
        syncedAt:              Date(),
        totalCiphers:          0,
        failedDecryptionCount: 0
    )
    nonisolated(unsafe) var syncShouldThrow: Error?

    // MARK: - SyncRepository

    func sync(progress: @Sendable @escaping (String) -> Void) async throws -> SyncResult {
        syncCalled = true
        if let err = syncShouldThrow { throw err }
        progress("Syncing vault…")
        progress("Decrypting…")
        progressMessages = ["Syncing vault…", "Decrypting…"]
        return stubbedSyncResult
    }
}
