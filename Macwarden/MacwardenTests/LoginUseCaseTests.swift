import XCTest
@testable import Macwarden

/// Tests for LoginUseCaseImpl.
///
/// After the background-sync-service refactor, LoginUseCaseImpl no longer calls sync.
/// Sync is triggered by LoginViewModel/RootViewModel after the flow transitions to .vault.
@MainActor
final class LoginUseCaseTests: XCTestCase {

    private var sut: LoginUseCaseImpl!
    private var mockAuth: MockAuthRepository!

    private let serverURL      = "https://vault.example.com"
    private let email          = "alice@example.com"
    private let masterPassword = Data("masterPassword1!".utf8)

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        sut = LoginUseCaseImpl(auth: mockAuth)
    }

    // MARK: - execute(serverURL:email:masterPassword:)

    /// Full success path: validates URL, sets environment, calls loginWithPassword, returns .success.
    /// Sync is NOT called from the use case — that is now SyncService's responsibility.
    func testExecute_validCredentials_returnsSuccess() async throws {
        mockAuth.stubbedLoginResult = .success(makeAccount())

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
    }

    /// When loginWithPassword returns .requiresTwoFactor, the use case returns the same result.
    func testExecute_requires2FA_returnsTwoFactor() async throws {
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
}
