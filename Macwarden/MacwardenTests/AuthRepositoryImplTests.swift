import XCTest
@testable import Macwarden

/// Failing tests for AuthRepositoryImpl (T023, T024).
/// These will fail until AuthRepositoryImpl + MacwardenAPIClient are implemented (T027–T029).
@MainActor
final class AuthRepositoryImplTests: XCTestCase {

    private var sut: AuthRepositoryImpl!
    private var mockAPI: MockMacwardenAPIClient!
    private var mockCrypto: MockMacwardenCryptoService!
    private var mockKeychain: MockKeychainService!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI      = MockMacwardenAPIClient()
        mockCrypto   = MockMacwardenCryptoService()
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

    /// storedAccount returns a populated Account when valid session data is in Keychain.
    func testStoredAccount_withSession_returnsAccount() throws {
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        let envJSON = String(data: try JSONEncoder().encode(env), encoding: .utf8)!
        mockKeychain.seed(key: "bw.macos:activeUserId",            value: "user-001")
        mockKeychain.seed(key: "bw.macos:user-001:email",          value: "alice@example.com")
        mockKeychain.seed(key: "bw.macos:user-001:serverEnvironment", value: envJSON)

        let account = sut.storedAccount()
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.email, "alice@example.com")
        XCTAssertEqual(account?.userId, "user-001")
    }

    // MARK: - T037: unlockWithPassword

    /// unlockWithPassword derives master key locally, decrypts vault key, unlocks crypto service.
    func testUnlockWithPassword_validPassword_unlocksCrypto() async throws {
        let userId = "user-001"
        let env    = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        let kdf    = KdfParams(type: .pbkdf2, iterations: 600_000, memory: nil, parallelism: nil)

        mockKeychain.seed(key: "bw.macos:activeUserId",                value: userId)
        mockKeychain.seed(key: "bw.macos:\(userId):email",             value: "alice@example.com")
        mockKeychain.seed(key: "bw.macos:\(userId):encUserKey",        value: "2.encKey==")
        mockKeychain.seed(key: "bw.macos:\(userId):kdfParams",
                          value: String(data: try JSONEncoder().encode(kdf), encoding: .utf8)!)
        mockKeychain.seed(key: "bw.macos:\(userId):serverEnvironment",
                          value: String(data: try JSONEncoder().encode(env), encoding: .utf8)!)

        let account = try await sut.unlockWithPassword("masterPassword1!")

        XCTAssertEqual(account.email, "alice@example.com")
        XCTAssertEqual(account.userId, userId)
        let isUnlocked = mockCrypto.isUnlocked
        XCTAssertTrue(isUnlocked, "Crypto service should be unlocked after successful unlock")
    }

    /// unlockWithPassword throws .invalidCredentials when no active session exists.
    func testUnlockWithPassword_noSession_throws() async throws {
        await XCTAssertThrowsErrorAsync(
            try await sut.unlockWithPassword("any")
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    // MARK: - T038: signOut (comprehensive)

    /// signOut clears all per-user Keychain keys and the global activeUserId.
    func testSignOut_clearsKeychain() async throws {
        try await sut.signOut()
        XCTAssertTrue(mockKeychain.deletedKeys.contains("bw.macos:activeUserId"))
    }

    /// signOut clears all seven per-user keys when a session exists.
    func testSignOut_withActiveSession_clearsAllUserKeys() async throws {
        let userId = "user-001"
        mockKeychain.seed(key: "bw.macos:activeUserId", value: userId)
        for suffix in ["accessToken", "refreshToken", "encUserKey", "kdfParams",
                       "email", "name", "serverEnvironment"] {
            mockKeychain.seed(key: "bw.macos:\(userId):\(suffix)", value: "value")
        }

        try await sut.signOut()

        for suffix in ["accessToken", "refreshToken", "encUserKey", "kdfParams",
                       "email", "name", "serverEnvironment"] {
            XCTAssertTrue(
                mockKeychain.deletedKeys.contains("bw.macos:\(userId):\(suffix)"),
                "Expected key bw.macos:\(userId):\(suffix) to be deleted on signOut"
            )
        }
        XCTAssertTrue(mockKeychain.deletedKeys.contains("bw.macos:activeUserId"))
    }

    /// After signOut, storedAccount() returns nil.
    func testSignOut_thenStoredAccount_returnsNil() async throws {
        mockKeychain.seed(key: "bw.macos:activeUserId", value: "user-001")
        try await sut.signOut()
        XCTAssertNil(sut.storedAccount())
    }

    /// signOut locks the vault (releases crypto key material).
    func testSignOut_locksVault() async throws {
        await mockCrypto.unlockWith(keys: CryptoKeys(encryptionKey: Data(count: 32), macKey: Data(count: 32)))
        try await sut.signOut()
        let isUnlocked = mockCrypto.isUnlocked
        XCTAssertFalse(isUnlocked, "Vault should be locked after signOut")
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
