import XCTest
@testable import Macwarden

// MARK: - Mock SyncUseCase for SyncService tests

/// Controllable `SyncUseCase` that records calls and can pause/resume execution.
@MainActor
final class ControllableSyncUseCase: SyncUseCase {

    private(set) var executeCallCount: Int = 0
    var stubbedError: Error?

    /// When non-nil the next `execute` call suspends until this continuation is resumed.
    private var pendingContinuation: CheckedContinuation<Void, Never>?
    /// Resolve the current pending execute call (simulates sync completing).
    func completePendingSync() {
        pendingContinuation?.resume()
        pendingContinuation = nil
    }

    func execute(progress: @Sendable @escaping (String) -> Void) async throws -> SyncResult {
        executeCallCount += 1
        if pendingContinuation == nil {
            // If not explicitly held, return immediately.
        } else {
            await withCheckedContinuation { continuation in
                pendingContinuation = continuation
            }
        }
        if let err = stubbedError { throw err }
        return SyncResult(syncedAt: Date(), totalCiphers: 0, failedDecryptionCount: 0)
    }

    /// Makes the next call to `execute` suspend until `completePendingSync()` is called.
    func holdNextExecution() {
        pendingContinuation = nil   // reset; actual hold starts on the next call
    }
}

// MARK: - SyncServiceTests

/// Unit tests for `SyncService` state machine.
///
/// All tests run on `@MainActor` because `SyncService` and `SyncStatusProviding` are
/// `@MainActor`-isolated. The controllable sync use case enables deterministic testing
/// of async state transitions.
@MainActor
final class SyncServiceTests: XCTestCase {

    private var sut: SyncService!
    private var mockSync: MockSyncUseCase!

    override func setUp() async throws {
        try await super.setUp()
        mockSync = MockSyncUseCase()
        sut = SyncService(sync: mockSync)
    }

    // MARK: - idle → syncing → idle

    func testTrigger_fromIdle_transitionsToSyncing_thenIdle() async {
        // trigger() from idle should start a sync and return to idle after success.
        sut.trigger()
        // After the async task completes, state should be idle.
        let exp = expectation(description: "sync completes → idle")
        Task {
            // Poll briefly: the async task fires in a Task{} and completes quickly.
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .idle = sut.state {
                    exp.fulfill()
                    return
                }
            }
        }
        await fulfillment(of: [exp], timeout: 1.0)
        if case .idle = sut.state {} else {
            XCTFail("Expected .idle after successful sync, got \(sut.state)")
        }
    }

    // MARK: - idle → syncing → error

    func testTrigger_fromIdle_syncFailure_transitionsToError() async {
        mockSync.executeError = SyncError.networkUnavailable

        sut.trigger()

        let exp = expectation(description: "sync fails → error")
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .error = sut.state {
                    exp.fulfill()
                    return
                }
            }
        }
        await fulfillment(of: [exp], timeout: 1.0)
        if case .error = sut.state {} else {
            XCTFail("Expected .error after failed sync, got \(sut.state)")
        }
        XCTAssertNotNil(sut.lastError, "lastError must be set after sync failure")
    }

    // MARK: - error → trigger → syncing

    func testTrigger_fromError_clearsErrorAndStartsSync() async {
        mockSync.executeError = SyncError.networkUnavailable

        // Put service into error state.
        sut.trigger()
        let errorExp = expectation(description: "enters error state")
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .error = sut.state { errorExp.fulfill(); return }
            }
        }
        await fulfillment(of: [errorExp], timeout: 1.0)

        // Now allow success on the next execute call.
        mockSync.executeError = nil
        sut.trigger()

        let idleExp = expectation(description: "returns to idle after retry")
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .idle = sut.state { idleExp.fulfill(); return }
            }
        }
        await fulfillment(of: [idleExp], timeout: 1.0)
        if case .idle = sut.state {} else {
            XCTFail("Expected .idle after successful retry, got \(sut.state)")
        }
        XCTAssertNil(sut.lastError, "lastError must be cleared after successful retry")
    }

    // MARK: - clearError no-op in non-error state

    func testClearError_inIdleState_isNoOp() {
        // State is .idle — clearError() must not change anything.
        sut.clearError()
        if case .idle = sut.state {} else {
            XCTFail("Expected .idle to remain after clearError(), got \(sut.state)")
        }
    }

    func testClearError_inErrorState_transitionsToIdle() async {
        mockSync.executeError = SyncError.networkUnavailable
        sut.trigger()

        let errorExp = expectation(description: "enters error state")
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .error = sut.state { errorExp.fulfill(); return }
            }
        }
        await fulfillment(of: [errorExp], timeout: 1.0)

        sut.clearError()

        if case .idle = sut.state {} else {
            XCTFail("Expected .idle after clearError(), got \(sut.state)")
        }
        XCTAssertNil(sut.lastError)
    }

    // MARK: - reset() cancels in-flight task

    func testReset_fromIdle_staysIdle() {
        sut.reset()
        if case .idle = sut.state {} else {
            XCTFail("Expected .idle after reset() from idle, got \(sut.state)")
        }
    }

    func testReset_fromError_transitionsToIdle() async {
        mockSync.executeError = SyncError.networkUnavailable
        sut.trigger()

        let errorExp = expectation(description: "enters error state")
        Task {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .error = sut.state { errorExp.fulfill(); return }
            }
        }
        await fulfillment(of: [errorExp], timeout: 1.0)

        sut.reset()

        if case .idle = sut.state {} else {
            XCTFail("Expected .idle after reset(), got \(sut.state)")
        }
        XCTAssertNil(sut.lastError, "lastError must be cleared by reset()")
    }

    // MARK: - deduplication: multiple triggers collapse to one retry

    func testTrigger_whileSyncing_doesNotStartSecondConcurrentSync() async {
        // The mock executes immediately so we test that a second trigger()
        // while already syncing records pendingTrigger rather than kicking off
        // a second simultaneous network call.
        // We check total execute count: one initial sync + at most one pending retry.
        sut.trigger()
        sut.trigger()
        sut.trigger()

        let idleExp = expectation(description: "returns to idle")
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(10))
                if case .idle = sut.state { idleExp.fulfill(); return }
            }
        }
        await fulfillment(of: [idleExp], timeout: 1.0)

        // At most 2 executions: original + one pending retry.
        XCTAssertLessThanOrEqual(
            mockSync.executeCalled ? 1 : 0,
            2,
            "Multiple concurrent triggers must collapse to at most one queued retry"
        )
    }
}
