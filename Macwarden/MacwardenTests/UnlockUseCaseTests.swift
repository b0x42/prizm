import XCTest
@testable import Macwarden

/// Failing tests for UnlockUseCaseImpl (T039).
/// These will fail until UnlockUseCaseImpl is implemented (T041).
@MainActor
final class UnlockUseCaseTests: XCTestCase {

    private var sut:      UnlockUseCaseImpl!
    private var mockAuth: MockAuthRepository!
    private var mockSync: MockSyncRepository!

    private let masterPassword = "masterPassword1!"

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        mockSync = MockSyncRepository()
        sut      = UnlockUseCaseImpl(auth: mockAuth, sync: mockSync)
    }

    // MARK: - T039: execute(masterPassword:)

    /// Full success path: unlocks vault locally, syncs to repopulate in-memory store.
    func testExecute_validPassword_returnsAccountAndSyncs() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())
        mockSync.stubbedSyncResult  = makeSyncResult()

        let account = try await sut.execute(masterPassword: masterPassword)

        XCTAssertEqual(account.email, "alice@example.com")
        XCTAssertTrue(mockAuth.unlockWithPasswordCalled, "Expected unlockWithPassword to be called")
        XCTAssertTrue(mockSync.syncCalled,               "Expected sync to re-populate vault after unlock")
    }

    /// Wrong master password propagates as AuthError.invalidCredentials without syncing.
    func testExecute_wrongPassword_throwsWithoutSync() async throws {
        mockAuth.unlockWithPasswordError = AuthError.invalidCredentials

        await XCTAssertThrowsErrorAsync(
            try await sut.execute(masterPassword: "wrong!")
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
        XCTAssertFalse(mockSync.syncCalled, "Sync must not be called after failed unlock")
    }

    /// Sync failure after successful unlock is propagated.
    func testExecute_syncFailure_throws() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())
        mockSync.syncShouldThrow    = SyncError.networkUnavailable

        await XCTAssertThrowsErrorAsync(
            try await sut.execute(masterPassword: masterPassword)
        ) { error in
            XCTAssertEqual(error as? SyncError, .networkUnavailable)
        }
    }

    /// Vault lock is NOT called on wrong password — the session stays intact (FR-039).
    func testExecute_wrongPassword_doesNotLockVault() async throws {
        mockAuth.unlockWithPasswordError   = AuthError.invalidCredentials
        mockAuth.lockVaultCalledCount      = 0

        _ = try? await sut.execute(masterPassword: "wrong!")

        XCTAssertEqual(mockAuth.lockVaultCalledCount, 0,
                       "lockVault must not be called on wrong password — session stays intact")
    }

    // MARK: - Helpers

    private func makeAccount() -> Account {
        Account(
            userId:            "user-001",
            email:             "alice@example.com",
            name:              nil,
            serverEnvironment: ServerEnvironment(
                base:      URL(string: "https://vault.example.com")!,
                overrides: nil
            )
        )
    }

    private func makeSyncResult() -> SyncResult {
        SyncResult(syncedAt: Date(), totalCiphers: 0, failedDecryptionCount: 0)
    }
}
