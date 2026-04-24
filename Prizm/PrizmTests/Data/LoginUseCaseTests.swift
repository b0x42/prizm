import XCTest
@testable import Prizm

@MainActor
final class LoginUseCaseTests: XCTestCase {

    private var sut: LoginUseCaseImpl!
    private var mockAuth: MockAuthRepository!
    private var mockSync: MockSyncRepository!

    private let selfHostedEnv = ServerEnvironment(
        base: URL(string: "https://vault.example.com")!,
        overrides: nil
    )
    private let email          = "alice@example.com"
    private let masterPassword = Data("masterPassword1!".utf8)

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        mockSync = MockSyncRepository()
        sut = LoginUseCaseImpl(auth: mockAuth, sync: mockSync)
    }

    // MARK: - execute: self-hosted success path

    func testExecute_validCredentials_returnsSuccessAndSyncs() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())
        mockSync.stubbedSyncResult  = makeSyncResult()

        let result = try await sut.execute(
            environment:    selfHostedEnv,
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

    // MARK: - execute: self-hosted URL validation

    func testExecute_selfHosted_invalidURL_throwsBeforeNetwork() async throws {
        mockAuth.validateServerURLError = AuthError.invalidURL

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.execute(
                environment:    selfHostedEnv,
                email:          email,
                masterPassword: masterPassword
            )
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidURL)
        }

        XCTAssertFalse(mockAuth.loginWithPasswordCalled, "Login must not be called on invalid URL")
        XCTAssertFalse(mockSync.syncCalled,              "Sync must not be called on invalid URL")
    }

    // MARK: - 8.4: cloud skips validateServerURL

    func testExecute_cloudUS_doesNotCallValidateServerURL() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())

        _ = try await sut.execute(
            environment:    .cloudUS(),
            email:          email,
            masterPassword: masterPassword
        )

        XCTAssertFalse(mockAuth.validateServerURLCalled,
                       "validateServerURL must NOT be called for cloud environments")
    }

    // MARK: - 8.5: self-hosted calls validateServerURL

    func testExecute_selfHosted_callsValidateServerURL() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())

        _ = try await sut.execute(
            environment:    selfHostedEnv,
            email:          email,
            masterPassword: masterPassword
        )

        XCTAssertTrue(mockAuth.validateServerURLCalled,
                      "validateServerURL must be called for self-hosted environments")
    }

    // MARK: - execute: 2FA

    func testExecute_requires2FA_returnsTwoFactorWithoutSync() async throws {
        mockAuth.stubbedLoginResult = .requiresTwoFactor(.authenticatorApp)

        let result = try await sut.execute(
            environment:    selfHostedEnv,
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

    // MARK: - execute: new-device OTP

    func testExecute_requiresNewDeviceOTP_returnsOTPWithoutSync() async throws {
        mockAuth.stubbedLoginResult = .requiresNewDeviceOTP

        let result = try await sut.execute(
            environment:    .cloudUS(),
            email:          email,
            masterPassword: masterPassword
        )

        guard case .requiresNewDeviceOTP = result else {
            return XCTFail("Expected .requiresNewDeviceOTP, got \(result)")
        }
        XCTAssertFalse(mockSync.syncCalled, "Sync must not be called when OTP is required")
    }

    // MARK: - execute: invalid credentials

    func testExecute_invalidCredentials_throws() async throws {
        mockAuth.loginWithPasswordError = AuthError.invalidCredentials

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.execute(
                environment:    selfHostedEnv,
                email:          email,
                masterPassword: masterPassword
            )
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }

        XCTAssertFalse(mockSync.syncCalled, "Sync must not be called on failed login")
    }

    // MARK: - execute: sync failure is non-fatal

    func testExecute_syncFailure_stillReturnsSuccess() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())
        mockSync.syncShouldThrow    = SyncError.networkUnavailable

        let result = try await sut.execute(
            environment:    selfHostedEnv,
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

    func testCancelTOTP_callsCancelTwoFactor() async throws {
        mockAuth.stubbedLoginResult = .requiresTwoFactor(.authenticatorApp)
        _ = try await sut.execute(
            environment:    selfHostedEnv,
            email:          email,
            masterPassword: masterPassword
        )

        sut.cancelTOTP()

        XCTAssertTrue(mockAuth.cancelTwoFactorCalled,
                      "cancelTOTP must forward to auth.cancelTwoFactor")
    }

    // MARK: - 8.11: completeNewDeviceOTP triggers sync

    func testCompleteNewDeviceOTP_triggersSync() async throws {
        let account = try await sut.completeNewDeviceOTP(otp: "123456")
        XCTAssertTrue(mockAuth.loginWithNewDeviceOTPCalled, "Expected loginWithNewDeviceOTP to be called")
        XCTAssertTrue(mockSync.syncCalled,                  "Expected sync after OTP success")
        XCTAssertEqual(account.email, mockAuth.stubbedLoginResult.account?.email)
    }

    // MARK: - 8.12: cancelNewDeviceOTP delegates to auth

    func testCancelNewDeviceOTP_callsAuthCancel() {
        sut.cancelNewDeviceOTP()
        XCTAssertTrue(mockAuth.cancelNewDeviceOTPCalled)
    }

    // MARK: - 8.13: resendNewDeviceOTP delegates to auth

    func testResendNewDeviceOTP_callsAuthRequest() async throws {
        try await sut.resendNewDeviceOTP()
        XCTAssertTrue(mockAuth.requestNewDeviceOTPCalled)
    }

    // MARK: - Helpers

    private func makeAccount() -> Account {
        Account(
            userId:            "user-guid-001",
            email:             email,
            name:              "Alice",
            serverEnvironment: selfHostedEnv
        )
    }

    private func makeSyncResult() -> SyncResult {
        SyncResult(syncedAt: Date(), totalCiphers: 0, failedDecryptionCount: 0)
    }
}

// MARK: - LoginResult helper for tests

private extension LoginResult {
    var account: Account? {
        if case .success(let a) = self { return a }
        return nil
    }
}
