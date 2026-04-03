import Foundation
@testable import Prizm

/// Test double for `SyncUseCase`.
final class MockSyncUseCase: SyncUseCase {

    private(set) var executeCalled: Bool = false
    var stubbedResult: SyncResult = SyncResult(syncedAt: Date(), totalCiphers: 0, failedDecryptionCount: 0)
    var executeError: Error?

    func execute(progress: @Sendable @escaping (String) -> Void) async throws -> SyncResult {
        executeCalled = true
        if let err = executeError { throw err }
        return stubbedResult
    }
}
