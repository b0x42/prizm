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

    /// validateServerURL rejects http:// - HTTPS only (Constitution §III).
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
        mockAPI.tokenTwoFactorProviders = [3]   // Duo - not supported in v1
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

    // MARK: - Multi-account profiles

    func testLogin_sameRemoteUserOnDifferentInstances_keepsDistinctProfiles() async throws {
        mockAPI.preLoginResponse = PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
        mockCrypto.stubbedServerHash = "hash=="

        for host in ["one.example.com", "two.example.com"] {
            try await sut.setServerEnvironment(
                ServerEnvironment(base: URL(string: "https://\(host)")!, overrides: nil)
            )
            mockAPI.tokenResponse = TokenResponse(
                accessToken: "access-\(host)", refreshToken: "refresh-\(host)",
                tokenType: "Bearer", expiresIn: 3600, key: "2.encUserKey==",
                privateKey: nil, kdf: 0, kdfIterations: 600_000,
                kdfMemory: nil, kdfParallelism: nil, twoFactorToken: nil,
                twoFactorProviders: nil, userId: "same-remote-user",
                email: "alice@example.com", name: "Alice"
            )
            _ = try await sut.loginWithPassword(
                email: "alice@example.com",
                masterPassword: Data("password".utf8)
            )
        }

        let accounts = sut.storedAccounts()
        XCTAssertEqual(accounts.count, 2)
        XCTAssertEqual(Set(accounts.map(\.profileId)).count, 2)
        XCTAssertEqual(
            Set(accounts.compactMap { $0.serverEnvironment.base.host }),
            ["one.example.com", "two.example.com"]
        )
    }

    func testActivateAccount_switchesWithoutDeletingOtherProfile() async throws {
        let first = try await loginProfile(host: "one.example.com", remoteUserId: "user-1")
        let second = try await loginProfile(host: "two.example.com", remoteUserId: "user-2")

        try await sut.activateAccount(profileId: first.profileId)

        XCTAssertEqual(sut.activeAccount()?.profileId, first.profileId)
        XCTAssertEqual(Set(sut.storedAccounts().map(\.profileId)), [first.profileId, second.profileId])
        XCTAssertNil(mockAPI.baseURL, "Selecting a locked profile must not activate networking")
    }

    func testStoredAccounts_migratesLegacyAccountOnce() throws {
        let env = ServerEnvironment(base: URL(string: "https://legacy.example.com")!, overrides: nil)
        mockKeychain.seed(key: "bw.macos:activeUserId", value: "legacy-user")
        mockKeychain.seed(key: "bw.macos:legacy-user:email", value: "legacy@example.com")
        mockKeychain.seed(
            key: "bw.macos:legacy-user:serverEnvironment",
            data: try JSONEncoder().encode(env)
        )

        let firstRead = sut.storedAccounts()
        let secondRead = sut.storedAccounts()

        XCTAssertEqual(firstRead.count, 1)
        XCTAssertEqual(secondRead, firstRead)
        XCTAssertNotNil(sut.activeAccount())
        XCTAssertTrue(mockKeychain.writtenKeys.contains("bw.macos:accountsIndex"))
        XCTAssertTrue(mockKeychain.writtenKeys.contains("bw.macos:activeProfileId"))
    }

    func testStoredAccounts_recoversInterruptedMigrationMissingActiveProfile() throws {
        let account = Account(
            userId: "user-1",
            email: "alice@example.com",
            name: nil,
            serverEnvironment: ServerEnvironment(
                base: URL(string: "https://vault.example.com")!,
                overrides: nil
            )
        )
        mockKeychain.seed(
            key: "bw.macos:accountsIndex",
            data: try JSONEncoder().encode([account])
        )

        XCTAssertEqual(sut.storedAccounts(), [account])
        XCTAssertEqual(sut.activeAccount(), account)
        XCTAssertTrue(mockKeychain.writtenKeys.contains("bw.macos:activeProfileId"))
    }

    func testStoredAccounts_retriesInterruptedLegacyCredentialCleanup() throws {
        let account = Account(
            userId: "legacy-user",
            email: "alice@example.com",
            name: nil,
            serverEnvironment: ServerEnvironment(
                base: URL(string: "https://vault.example.com")!,
                overrides: nil
            )
        )
        mockKeychain.seed(key: "bw.macos:accountsIndex", data: try JSONEncoder().encode([account]))
        mockKeychain.seed(key: "bw.macos:activeProfileId", value: account.profileId.uuidString)
        mockKeychain.seed(key: "bw.macos:activeUserId", value: "legacy-user")
        let legacyRefreshKey = "bw.macos:legacy-user:refreshToken"
        mockKeychain.seed(key: legacyRefreshKey, value: "legacy-refresh")
        mockKeychain.deleteErrors[legacyRefreshKey] = KeychainError.invalidData

        _ = sut.storedAccounts()
        XCTAssertNoThrow(try mockKeychain.read(key: "bw.macos:activeUserId"))

        mockKeychain.deleteErrors.removeValue(forKey: legacyRefreshKey)
        _ = sut.storedAccounts()
        XCTAssertThrowsError(try mockKeychain.read(key: "bw.macos:activeUserId"))
        XCTAssertTrue(mockKeychain.deletedKeys.contains(legacyRefreshKey))
    }

    private func loginProfile(host: String, remoteUserId: String) async throws -> Account {
        try await sut.setServerEnvironment(
            ServerEnvironment(base: URL(string: "https://\(host)")!, overrides: nil)
        )
        mockAPI.preLoginResponse = PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
        mockAPI.tokenResponse = TokenResponse(
            accessToken: "access-\(host)", refreshToken: "refresh-\(host)",
            tokenType: "Bearer", expiresIn: 3600, key: "2.encUserKey==",
            privateKey: nil, kdf: 0, kdfIterations: 600_000,
            kdfMemory: nil, kdfParallelism: nil, twoFactorToken: nil,
            twoFactorProviders: nil, userId: remoteUserId,
            email: "\(remoteUserId)@example.com", name: nil
        )
        let result = try await sut.loginWithPassword(
            email: "\(remoteUserId)@example.com",
            masterPassword: Data("password".utf8)
        )
        guard case .success(let account) = result else {
            throw AuthError.invalidCredentials
        }
        return account
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

    /// unlockWithPassword reads the email key exactly once - not once directly and again
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

    func testUnlockCanceledByLock_cannotReactivatePreviousProfile() async throws {
        let userId = "user-001"
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        let kdf = KdfParams(type: .pbkdf2, iterations: 600_000, memory: nil, parallelism: nil)
        mockKeychain.seed(key: "bw.macos:activeUserId", value: userId)
        mockKeychain.seed(key: "bw.macos:\(userId):email", value: "alice@example.com")
        mockKeychain.seed(key: "bw.macos:\(userId):encUserKey", value: "2.encKey==")
        mockKeychain.seed(
            key: "bw.macos:\(userId):kdfParams",
            data: try JSONEncoder().encode(kdf)
        )
        mockKeychain.seed(
            key: "bw.macos:\(userId):serverEnvironment",
            data: try JSONEncoder().encode(env)
        )
        mockCrypto.masterKeyDelay = 0.1

        let unlock = Task {
            try await sut.unlockWithPassword(Data("password".utf8))
        }
        try await Task.sleep(for: .milliseconds(10))
        await sut.lockVault()

        await XCTAssertThrowsErrorAsync(try await unlock.value) { error in
            XCTAssertEqual(error as? APIError, .sessionInvalidated)
        }
        XCTAssertFalse(mockCrypto.isUnlocked)
        XCTAssertNil(mockAPI.baseURL)
    }

    // MARK: - T038: signOut (comprehensive)

    /// signOut is a safe no-op when no profile is active.
    func testSignOut_withoutActiveProfile_isSafe() async throws {
        try await sut.signOut()
        XCTAssertNil(sut.activeAccount())
    }

    /// signOut migrates then removes an active legacy profile and all of its local keys.
    func testSignOut_withActiveSession_clearsAllUserKeys() async throws {
        let userId = "user-001"
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        mockKeychain.seed(key: "bw.macos:activeUserId", value: userId)
        mockKeychain.seed(key: "bw.macos:\(userId):email", value: "alice@example.com")
        mockKeychain.seed(key: "bw.macos:\(userId):serverEnvironment", data: try JSONEncoder().encode(env))
        mockKeychain.seed(key: "bw.macos:\(userId):accessToken", value: "token")

        try await sut.signOut()

        XCTAssertTrue(mockKeychain.deletedKeys.contains("bw.macos:activeUserId"))
        XCTAssertTrue(sut.storedAccounts().isEmpty)
        XCTAssertNil(sut.activeAccount())
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
