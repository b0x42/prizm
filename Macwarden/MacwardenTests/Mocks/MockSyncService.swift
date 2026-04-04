import Foundation
@testable import Macwarden

/// Test double for `SyncStatusProviding`.
///
/// Records calls to `trigger()`, `clearError()`, and `reset()` for use in
/// ViewModel tests that assert sync is triggered after auth success or mutations.
@MainActor
final class MockSyncService: SyncStatusProviding {

    private(set) var triggerCallCount: Int = 0
    private(set) var clearErrorCallCount: Int = 0
    private(set) var resetCallCount: Int = 0

    var state: SyncState = .idle
    var lastError: Error? = nil

    func trigger() {
        triggerCallCount += 1
    }

    func clearError() {
        clearErrorCallCount += 1
    }

    func reset() {
        resetCallCount += 1
    }
}
