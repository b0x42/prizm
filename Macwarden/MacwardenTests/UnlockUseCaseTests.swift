import XCTest
@testable import Macwarden

/// Tests for UnlockUseCaseImpl.
///
/// After the background-sync-service refactor, UnlockUseCaseImpl no longer calls sync.
/// Sync is triggered by UnlockViewModel via SyncService.trigger() after the flow
/// transitions to .vault.
@MainActor
final class UnlockUseCaseTests: XCTestCase {

    private var sut:      UnlockUseCaseImpl!
    private var mockAuth: MockAuthRepository!

    private let masterPassword = Data("masterPassword1!".utf8)

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        sut      = UnlockUseCaseImpl(auth: mockAuth)
    }

    // MARK: - execute(masterPassword:)

    /// Full success path: unlocks vault locally and returns the account.
    /// Sync is NOT called from the use case — that is now SyncService's responsibility.
    func testExecute_validPassword_returnsAccount() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())

        let account = try await sut.execute(masterPassword: masterPassword)

        XCTAssertEqual(account.email, "alice@example.com")
        XCTAssertTrue(mockAuth.unlockWithPasswordCalled, "Expected unlockWithPassword to be called")
    }

    /// Wrong master password propagates as AuthError.invalidCredentials.
    func testExecute_wrongPassword_throws() async throws {
        mockAuth.unlockWithPasswordError = AuthError.invalidCredentials

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.execute(masterPassword: Data("wrong!".utf8))
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    /// Vault lock is NOT called on wrong password — the session stays intact (FR-039).
    func testExecute_wrongPassword_doesNotLockVault() async throws {
        mockAuth.unlockWithPasswordError   = AuthError.invalidCredentials
        mockAuth.lockVaultCalledCount      = 0

        _ = try? await sut.execute(masterPassword: Data("wrong!".utf8))

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
}
