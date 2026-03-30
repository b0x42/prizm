import Foundation
@testable import Macwarden

/// Test double for `SyncTimestampRepository`.
///
/// Stores the given `storedDate` and records whether `recordSuccessfulSync()` was called.
/// Shared across test targets so multiple test suites can reference the same mock without
/// duplicating the type definition.
final class MockSyncTimestampRepository: SyncTimestampRepository {
    private(set) var recordCalled = false
    private var storedDate: Date?

    init(storedDate: Date?) {
        self.storedDate = storedDate
    }

    var lastSyncDate: Date? { storedDate }

    func recordSuccessfulSync() {
        recordCalled = true
        storedDate = Date()
    }
}
