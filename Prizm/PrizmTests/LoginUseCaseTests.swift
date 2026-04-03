import XCTest
@testable import Prizm

/// Failing tests for LoginUseCaseImpl (T026).
/// These will fail until LoginUseCaseImpl + AuthRepositoryImpl + SyncRepositoryImpl are implemented.
@MainActor
final class LoginUseCaseTests: XCTestCase {

    private var sut: LoginUseCaseImpl!
    private var mockAuth: MockAuthRepository!
    private var mockSync: MockSyncRepository!

    private let serverURL      = "https://vault.example.com"
    private let email          = "alice@example.com"
    private let masterPassword = Data("masterPassword1!".utf8)

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        mockSync = MockSyncRepository()
        sut = LoginUseCaseImpl(auth: mockAuth, sync: mockSync)
    }

    // MARK: - T026: execute(serverURL:email:masterPassword:)

    /// Full success path: validates URL, sets environment, calls loginWithPassword, syncs, returns .success.
    func testExecute_validCredentials_returnsSuccessAndSyncs() async throws {
        mockAuth.stubbedLoginResult  = .success(makeAccount())
        mockSync.stubbedSyncResult   = makeSyncResult()

        let result = try await sut.execute(
            serverURL:      serverURL,
            email:          email,
            masterPassword: masterPassword
        )

        guard case .success(let account) = result else {
            return XCTFail("Expected .success, got \(result)")
        }
        XCTAssertEqual(account.email, email)
        XCTAssertTrue(mockAuth.setServerEnvironmentCalled, "Expected setServerEnvironment to be called")
        XCTAssertTrue(mockAuth.loginWithPasswordCalled,    "Expected loginWithPassword to be called")
        XCTAssertTrue(mockSync.syncCalled,                 "Expected sync to be called after login")
    }

    /// An invalid server URL is rejected before any network call is made.
    func testExecute_invalidURL_throwsBeforeNetwork() async throws {
        mockAuth.validateServerURLError = AuthError.invalidURL

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.execute(
                serverURL:      "not-a-url",
                email:          email,
                masterPassword: masterPassword
            )
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidURL)
        }

        XCTAssertFalse(mockAuth.loginWithPasswordCalled, "Login must not be called on invalid URL")
        XCTAssertFalse(mockSync.syncCalled,              "Sync must not be called on invalid URL")
    }

    /// When loginWithPassword returns .requiresTwoFactor, the use case returns the same result
    /// without triggering a sync.
    func testExecute_requires2FA_returnsTwoFactorWithoutSync() async throws {
        mockAuth.stubbedLoginResult = .requiresTwoFactor(.authenticatorApp)

        let result = try await sut.execute(
            serverURL:      serverURL,
            email:          email,
            masterPassword: masterPassword
        )

        guard case .requiresTwoFactor(let method) = result else {
            return XCTFail("Expected .requiresTwoFactor, got \(result)")
        }
        guard case .authenticatorApp = method else {
            return XCTFail("Expected .authenticatorApp, got \(method)")
        }
        XCTAssertFalse(mockSync.syncCalled, "Sync must not be called when 2FA is required")
    }

    /// Invalid credentials propagate as AuthError.invalidCredentials.
    func testExecute_invalidCredentials_throws() async throws {
        mockAuth.loginWithPasswordError = AuthError.invalidCredentials

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.execute(
                serverURL:      serverURL,
                email:          email,
                masterPassword: masterPassword
            )
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }

        XCTAssertFalse(mockSync.syncCalled, "Sync must not be called on failed login")
    }

    /// A sync failure after successful login is non-fatal — result is still .success (FR-049).
    func testExecute_syncFailure_throws() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())
        mockSync.syncShouldThrow    = SyncError.networkUnavailable

        let result = try await sut.execute(
            serverURL:      serverURL,
            email:          email,
            masterPassword: masterPassword
        )
        guard case .success = result else {
            XCTFail("Expected .success despite sync failure")
            return
        }
        XCTAssertTrue(mockSync.syncCalled, "Sync should still be attempted")
    }

    // MARK: - cancelTOTP

    /// cancelTOTP delegates to auth.cancelTwoFactor() — clears pending in-memory key material.
    func testCancelTOTP_callsCancelTwoFactor() async throws {
        mockAuth.stubbedLoginResult = .requiresTwoFactor(.authenticatorApp)
        _ = try await sut.execute(
            serverURL:      serverURL,
            email:          email,
            masterPassword: masterPassword
        )

        sut.cancelTOTP()

        XCTAssertTrue(mockAuth.cancelTwoFactorCalled,
                      "cancelTOTP must forward to auth.cancelTwoFactor to clear pending key material")
    }

    // MARK: - Helpers

    private func makeAccount() -> Account {
        Account(
            userId:            "user-guid-001",
            email:             email,
            name:              "Alice",
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
