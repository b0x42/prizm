import Foundation
@testable import Bitwarden_MacOS

/// Test double for `SyncRepository` — used by `LoginUseCaseTests`.
final class MockSyncRepository: SyncRepository {

    // MARK: - State observations

    private(set) var syncCalled: Bool = false
    private(set) var progressMessages: [String] = []

    // MARK: - Stubs

    var stubbedSyncResult: SyncResult = SyncResult(
        syncedAt:              Date(),
        totalCiphers:          0,
        failedDecryptionCount: 0
    )
    var syncShouldThrow: Error?

    // MARK: - SyncRepository

    func sync(progress: @escaping (String) -> Void) async throws -> SyncResult {
        syncCalled = true
        if let err = syncShouldThrow { throw err }
        progress("Syncing vault…")
        progress("Decrypting…")
        progressMessages = ["Syncing vault…", "Decrypting…"]
        return stubbedSyncResult
    }
}
