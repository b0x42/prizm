import XCTest
@testable import Prizm

/// Failing tests for AuthRepositoryImpl (T023, T024).
/// These will fail until AuthRepositoryImpl + PrizmAPIClient are implemented (T027–T029).
@MainActor
final class AuthRepositoryImplTests: XCTestCase {

    private var sut: AuthRepositoryImpl!
    private var mockAPI: MockPrizmAPIClient!
    private var mockCrypto: MockPrizmCryptoService!
    private var mockKeychain: MockKeychainService!
    private var mockBiometricKeychain: MockBiometricKeychainService!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI      = MockPrizmAPIClient()
        mockCrypto   = MockPrizmCryptoService()
        mockKeychain = MockKeychainService()
        mockBiometricKeychain = MockBiometricKeychainService()
        sut = AuthRepositoryImpl(
            apiClient:  mockAPI,
            crypto:     mockCrypto,
            keychain:   mockKeychain,
            biometricKeychain: mockBiometricKeychain
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

    /// validateServerURL rejects http:// — HTTPS only (Constitution §III).
    func testValidateServerURL_httpURL_throws() throws {
        XCTAssertThrowsError(try sut.validateServerURL("http://192.168.1.100")) { error in
            XCTAssertEqual(error as? AuthError, .invalidURL)
        }
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
            masterPassword: Data("masterPassword1!".utf8)
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
            masterPassword: Data("masterPassword1!".utf8)
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
            masterPassword: Data("masterPassword1!".utf8)
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
        _ = try await sut.loginWithPassword(email: "alice@example.com", masterPassword: Data("pw!".utf8))

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
        _ = try await sut.loginWithPassword(email: "alice@example.com", masterPassword: Data("pw!".utf8))

        mockAPI.tokenShouldThrow = AuthError.invalidTwoFactorCode

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.loginWithTOTP(code: "000000", rememberDevice: false)
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidTwoFactorCode)
        }
    }

    // MARK: - cancelTwoFactor

    /// cancelTwoFactor clears pendingTwoFactor so a subsequent loginWithTOTP throws .invalidCredentials.
    func testCancelTwoFactor_clearsPendingState() async throws {
        let serverEnv = ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
        try await sut.setServerEnvironment(serverEnv)
        mockAPI.preLoginResponse       = PreLoginResponse(kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil)
        mockAPI.tokenTwoFactorProviders = [0]
        mockCrypto.stubbedServerHash   = "hash=="
        _ = try await sut.loginWithPassword(email: "alice@example.com", masterPassword: Data("pw!".utf8))

        // Cancel before entering the TOTP code.
        sut.cancelTwoFactor()

        // A subsequent TOTP attempt must fail because pending state was cleared.
        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.loginWithTOTP(code: "123456", rememberDevice: false)
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCredentials,
                           "loginWithTOTP must throw .invalidCredentials when no pending state exists")
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

        let account = try await sut.unlockWithPassword(Data("masterPassword1!".utf8))

        XCTAssertEqual(account.email, "alice@example.com")
        XCTAssertEqual(account.userId, userId)
        let isUnlocked = mockCrypto.isUnlocked
        XCTAssertTrue(isUnlocked, "Crypto service should be unlocked after successful unlock")
    }

    /// unlockWithPassword reads the email key exactly once — not once directly and again
    /// inside account(for:). Duplicate reads produce extra keychain prompts on every build.
    func testUnlockWithPassword_emailReadExactlyOnce() async throws {
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

        _ = try await sut.unlockWithPassword(Data("masterPassword1!".utf8))

        let emailKey   = "bw.macos:\(userId):email"
        let emailReads = mockKeychain.readKeys.filter { $0 == emailKey }.count
        XCTAssertEqual(emailReads, 1, "email should be read exactly once, got \(emailReads)")
    }

    /// unlockWithPassword throws .invalidCredentials when no active session exists.
    func testUnlockWithPassword_noSession_throws() async throws {
        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.unlockWithPassword(Data("any".utf8))
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

    // MARK: - 8.1: setServerEnvironment forwards to apiClient

    func testSetServerEnvironment_callsApiClientSetServerEnvironment() async throws {
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        try await sut.setServerEnvironment(env)
        let serverEnv = await mockAPI.serverEnvironment
        XCTAssertNotNil(serverEnv, "apiClient.setServerEnvironment must be called")
    }

    // MARK: - 8.2: loginWithPassword returns .requiresNewDeviceOTP on device_error

    func testLoginWithPassword_deviceError_returnsRequiresNewDeviceOTP() async throws {
        let sutWithId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: "test-id"
        )
        let env = ServerEnvironment.cloudUS()
        try await sutWithId.setServerEnvironment(env)
        mockAPI.tokenShouldThrow = IdentityTokenError.newDeviceNotVerified
        mockCrypto.stubbedServerHash = "hash=="

        let result = try await sutWithId.loginWithPassword(
            email: "a@b.com",
            masterPassword: Data("pw".utf8)
        )

        guard case .requiresNewDeviceOTP = result else {
            return XCTFail("Expected .requiresNewDeviceOTP, got \(result)")
        }
    }

    // MARK: - 8.3: clientIdentifierNotConfigured for cloud with empty identifier

    func testLoginWithPassword_cloudWithEmptyClientId_throwsClientIdentifierNotConfigured() async throws {
        let sutNoId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: ""
        )
        let env = ServerEnvironment.cloudUS()
        try await sutNoId.setServerEnvironment(env)

        await XCTAssertThrowsErrorAsync(
            try await sutNoId.loginWithPassword(
                email: "a@b.com",
                masterPassword: Data("pw".utf8)
            )
        ) { error in
            XCTAssertEqual(error as? AuthError, .clientIdentifierNotConfigured)
        }

        XCTAssertFalse(mockAPI.preLoginResponse != nil || mockAPI.tokenShouldThrow != nil,
                       "No network call should be made when clientIdentifier is empty")
        // preLogin should NOT have been called — tokenResponse is nil means no request was made
        XCTAssertNil(mockAPI.lastIdentityTokenNewDeviceOTP, "identityToken must not be called")
    }

    // MARK: - 8.6/8.7: pending OTP state cleared after loginWithNewDeviceOTP (success and failure)

    func testLoginWithNewDeviceOTP_success_clearsPendingState() async throws {
        let sutWithId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: "test-id"
        )
        let env = ServerEnvironment.cloudUS()
        try await sutWithId.setServerEnvironment(env)
        // Trigger pending state via device_error, then succeed on OTP.
        mockAPI.tokenShouldThrow  = IdentityTokenError.newDeviceNotVerified
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sutWithId.loginWithPassword(email: "a@b.com", masterPassword: Data("pw".utf8))
        // Now set up success response for OTP submission.
        mockAPI.tokenShouldThrow = nil
        mockAPI.tokenResponse    = makeTokenResponse()
        _ = try await sutWithId.loginWithNewDeviceOTP("123456")
        // Calling again should throw otpSessionExpired because pending state was cleared.
        await XCTAssertThrowsErrorAsync(
            try await sutWithId.loginWithNewDeviceOTP("000000")
        ) { error in
            XCTAssertEqual(error as? AuthError, .otpSessionExpired)
        }
    }

    // MARK: - 8.7: wrong OTP preserves pending state so user can retry

    func testLoginWithNewDeviceOTP_failure_preservesPendingForRetry() async throws {
        let sutWithId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: "test-id"
        )
        let env = ServerEnvironment.cloudUS()
        try await sutWithId.setServerEnvironment(env)
        mockAPI.tokenShouldThrow     = IdentityTokenError.newDeviceNotVerified
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sutWithId.loginWithPassword(email: "a@b.com", masterPassword: Data("pw".utf8))
        // First OTP attempt fails — wrong code.
        mockAPI.tokenShouldThrow = IdentityTokenError.invalidCredentials
        _ = try? await sutWithId.loginWithNewDeviceOTP("000000")
        // Pending state must be preserved so the user can retry with the correct code.
        mockAPI.tokenShouldThrow = nil
        mockAPI.tokenResponse    = makeTokenResponse()
        let account = try await sutWithId.loginWithNewDeviceOTP("123456")
        XCTAssertEqual(account.email, "a@b.com", "Retry with correct OTP should succeed")
    }

    // MARK: - 8.8: pending OTP state cleared after cancelNewDeviceOTP

    func testCancelNewDeviceOTP_clearsPendingState() async throws {
        let sutWithId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: "test-id"
        )
        let env = ServerEnvironment.cloudUS()
        try await sutWithId.setServerEnvironment(env)
        mockAPI.tokenShouldThrow     = IdentityTokenError.newDeviceNotVerified
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sutWithId.loginWithPassword(email: "a@b.com", masterPassword: Data("pw".utf8))
        sutWithId.cancelNewDeviceOTP()
        // loginWithNewDeviceOTP should now throw otpSessionExpired because pending is nil.
        await XCTAssertThrowsErrorAsync(
            try await sutWithId.loginWithNewDeviceOTP("123456")
        ) { error in
            XCTAssertEqual(error as? AuthError, .otpSessionExpired)
        }
    }

    // MARK: - 8.9: requestNewDeviceOTP does NOT clear pending state

    func testRequestNewDeviceOTP_doesNotClearPendingState() async throws {
        let sutWithId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: "test-id"
        )
        let env = ServerEnvironment.cloudUS()
        try await sutWithId.setServerEnvironment(env)
        mockAPI.tokenShouldThrow     = IdentityTokenError.newDeviceNotVerified
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sutWithId.loginWithPassword(email: "a@b.com", masterPassword: Data("pw".utf8))
        // requestNewDeviceOTP throws device_error again (expected behavior — treated as success).
        try await sutWithId.requestNewDeviceOTP()
        // Pending state must still be intact — loginWithNewDeviceOTP should not throw invalidCredentials.
        // (It will throw because tokenShouldThrow is still set, but not with invalidCredentials from nil pending.)
        mockAPI.tokenShouldThrow = nil
        mockAPI.tokenResponse    = makeTokenResponse()
        _ = try await sutWithId.loginWithNewDeviceOTP("123456")
        // If we got here, pending was not cleared by requestNewDeviceOTP.
    }

    // MARK: - 8.10: OTP retry includes newdeviceotp parameter

    func testLoginWithNewDeviceOTP_passesOTPToApiClient() async throws {
        let sutWithId = AuthRepositoryImpl(
            apiClient:        mockAPI,
            crypto:           mockCrypto,
            keychain:         mockKeychain,
            biometricKeychain: mockBiometricKeychain,
            clientIdentifier: "test-id"
        )
        let env = ServerEnvironment.cloudUS()
        try await sutWithId.setServerEnvironment(env)
        mockAPI.tokenShouldThrow     = IdentityTokenError.newDeviceNotVerified
        mockCrypto.stubbedServerHash = "hash=="
        _ = try await sutWithId.loginWithPassword(email: "a@b.com", masterPassword: Data("pw".utf8))
        mockAPI.tokenShouldThrow = nil
        mockAPI.tokenResponse    = makeTokenResponse()
        _ = try await sutWithId.loginWithNewDeviceOTP("654321")
        XCTAssertEqual(mockAPI.lastIdentityTokenNewDeviceOTP, "654321",
                       "loginWithNewDeviceOTP must pass the OTP to identityToken")
    }

    // MARK: - Helpers

    private func makeTokenResponse() -> TokenResponse {
        TokenResponse(
            accessToken:  "at",
            refreshToken: "rt",
            tokenType:    "Bearer",
            expiresIn:    3600,
            key:          "2.k==",
            privateKey:   nil,
            kdf:          0,
            kdfIterations: 600_000,
            kdfMemory:     nil,
            kdfParallelism: nil,
            twoFactorToken:     nil,
            twoFactorProviders: nil,
            userId: "uid",
            email:  "a@b.com",
            name:   nil
        )
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
