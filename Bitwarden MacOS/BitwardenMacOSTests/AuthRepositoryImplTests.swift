import XCTest
@testable import Bitwarden_MacOS

/// Failing tests for AuthRepositoryImpl (T023, T024).
/// These will fail until AuthRepositoryImpl + BitwardenAPIClient are implemented (T027–T029).
@MainActor
final class AuthRepositoryImplTests: XCTestCase {

    private var sut: AuthRepositoryImpl!
    private var mockAPI: MockBitwardenAPIClient!
    private var mockCrypto: MockBitwardenCryptoService!
    private var mockKeychain: MockKeychainService!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI      = MockBitwardenAPIClient()
        mockCrypto   = MockBitwardenCryptoService()
        mockKeychain = MockKeychainService()
        sut = AuthRepositoryImpl(
            apiClient:  mockAPI,
            crypto:     mockCrypto,
            keychain:   mockKeychain
        )
    }

    // MARK: - T023: loginWithPassword

    /// validateServerURL rejects a URL with no scheme.
    func testValidateServerURL_missingScheme_throws() {
        XCTAssertThrowsError(try sut.validateServerURL("vault.example.com")) { error in
            XCTAssertEqual(error as? AuthError, .invalidURL)
        }
    }

    /// validateServerURL accepts https:// and strips trailing slash.
    func testValidateServerURL_validHTTPS_succeeds() throws {
        XCTAssertNoThrow(try sut.validateServerURL("https://vault.example.com/"))
    }

    /// validateServerURL accepts http:// (for local dev).
    func testValidateServerURL_validHTTP_succeeds() throws {
        XCTAssertNoThrow(try sut.validateServerURL("http://192.168.1.100"))
    }

    /// Full loginWithPassword: preLogin → hashPassword → identityToken → initializeUserCrypto.
    /// Returns .success(Account) when server returns a valid token response with no 2FA.
    func testLoginWithPassword_success_returnsAccount() async throws {
        let serverEnv = ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
        try await sut.setServerEnvironment(serverEnv)

        // Arrange mock responses
        mockAPI.preLoginResponse = PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
        mockAPI.tokenResponse = TokenResponse(
            accessToken:  "access-token-abc",
            refreshToken: "refresh-token-xyz",
            tokenType:    "Bearer",
            expiresIn:    3600,
            key:          "2.encUserKey==",
            privateKey:   "2.encPrivateKey==",
            kdf:          0,
            kdfIterations: 600_000,
            kdfMemory:     nil,
            kdfParallelism: nil,
            twoFactorToken: nil,
            twoFactorProviders: nil,
            userId:       "user-guid-001",
            email:        "alice@example.com",
            name:         "Alice"
        )
        mockCrypto.stubbedServerHash = "base64serverhash=="

        let result = try await sut.loginWithPassword(
            email: "alice@example.com",
            masterPassword: "masterPassword1!"
        )

        guard case .success(let account) = result else {
            return XCTFail("Expected .success, got \(result)")
        }
        XCTAssertEqual(account.email, "alice@example.com")
        XCTAssertEqual(account.userId, "user-guid-001")
    }

    /// Returns .requiresTwoFactor(.authenticatorApp) when server sends 2FA challenge with provider 0.
    func testLoginWithPassword_2FARequired_returnsRequiresTwoFactor() async throws {
        let serverEnv = ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
        try await sut.setServerEnvironment(serverEnv)

        mockAPI.preLoginResponse = PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
        // Token endpoint returns 400 with 2FA providers
        mockAPI.tokenTwoFactorProviders = [0]   // authenticatorApp
        mockCrypto.stubbedServerHash = "hash=="

        let result = try await sut.loginWithPassword(
            email: "alice@example.com",
            masterPassword: "masterPassword1!"
        )

        guard case .requiresTwoFactor(let method) = result else {
            return XCTFail("Expected .requiresTwoFactor, got \(result)")
        }
        guard case .authenticatorApp = method else {
            return XCTFail("Expected .authenticatorApp, got \(method)")
        }
    }

    /// Returns .requiresTwoFactor(.unsupported) when server only offers non-TOTP methods.
    func testLoginWithPassword_unsupported2FA_returnsUnsupported() async throws {
        let serverEnv = ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
        try await sut.setServerEnvironment(serverEnv)

        mockAPI.preLoginResponse = PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
        mockAPI.tokenTwoFactorProviders = [3]   // Duo — not supported in v1
        mockCrypto.stubbedServerHash = "hash=="

        let result = try await sut.loginWithPassword(
            email: "alice@example.com",
            masterPassword: "masterPassword1!"
        )

        guard case .requiresTwoFactor(let method) = result else {
            return XCTFail("Expected .requiresTwoFactor")
        }
        guard case .unsupported = method else {
            return XCTFail("Expected .unsupported, got \(method)")
        }
    }

    // MARK: - T024: loginWithTOTP

    /// loginWithTOTP completes the 2FA challenge and returns the authenticated Account.
    func testLoginWithTOTP_correctCode_returnsAccount() async throws {
        let serverEnv = ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
        try await sut.setServerEnvironment(serverEnv)

        // Pre-stage the pending 2FA state (normally set by loginWithPassword returning .requiresTwoFactor)
        mockAPI.preLoginResponse = PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
        mockAPI.tokenTwoFactorProviders = [0]
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sut.loginWithPassword(email: "alice@example.com", masterPassword: "pw!")

        // Now provide the TOTP code
        mockAPI.tokenResponse = TokenResponse(
            accessToken: "access-totp", refreshToken: "refresh-totp", tokenType: "Bearer",
            expiresIn: 3600, key: "2.encUserKey==", privateKey: "2.encPrivateKey==",
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil,
            twoFactorToken: nil, twoFactorProviders: nil,
            userId: "user-guid-001", email: "alice@example.com", name: "Alice"
        )

        let account = try await sut.loginWithTOTP(code: "123456", rememberDevice: false)
        XCTAssertEqual(account.email, "alice@example.com")
    }

    /// loginWithTOTP with wrong code throws .invalidTwoFactorCode.
    func testLoginWithTOTP_wrongCode_throws() async throws {
        let serverEnv = ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
        try await sut.setServerEnvironment(serverEnv)
        mockAPI.preLoginResponse = PreLoginResponse(kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil)
        mockAPI.tokenTwoFactorProviders = [0]
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sut.loginWithPassword(email: "alice@example.com", masterPassword: "pw!")

        mockAPI.tokenShouldThrow = AuthError.invalidTwoFactorCode

        await XCTAssertThrowsErrorAsync(
            try await sut.loginWithTOTP(code: "000000", rememberDevice: false)
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidTwoFactorCode)
        }
    }

    // MARK: - storedAccount

    /// storedAccount returns nil when no activeUserId is in Keychain.
    func testStoredAccount_noSession_returnsNil() {
        XCTAssertNil(sut.storedAccount())
    }

    // MARK: - signOut

    /// signOut clears all per-user Keychain keys.
    func testSignOut_clearsKeychain() async throws {
        try await sut.signOut()
        XCTAssertTrue(mockKeychain.deletedKeys.contains("bw.macos:activeUserId"))
    }
}

// MARK: - Async XCTAssertThrowsError helper

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown" + (message.isEmpty ? "" : ": \(message)"),
                file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
