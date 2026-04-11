import XCTest
@testable import Prizm

/// Tests for `AuthRepositoryImpl` biometric unlock methods.
@MainActor
final class AuthRepositoryImplBiometricTests: XCTestCase {

    private var sut: AuthRepositoryImpl!
    private var mockAPI: MockPrizmAPIClient!
    private var mockCrypto: MockPrizmCryptoService!
    private var mockKeychain: MockKeychainService!
    private var mockBiometricKeychain: MockBiometricKeychainService!

    private let testUserId = "test-user-id"
    private let testEmail  = "test@example.com"
    private let testEnv    = ServerEnvironment(
        base: URL(string: "https://vault.example.com")!,
        overrides: nil
    )

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
        // Seed Keychain with a stored session so account(for:) works.
        seedStoredSession()
        // Clear UserDefaults between tests.
        UserDefaults.standard.removeObject(forKey: "biometricUnlockEnabled")
        UserDefaults.standard.removeObject(forKey: "biometricEnrollmentPromptShown")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "biometricUnlockEnabled")
        UserDefaults.standard.removeObject(forKey: "biometricEnrollmentPromptShown")
        try await super.tearDown()
    }

    // MARK: - enableBiometricUnlock

    func testEnableBiometricUnlock_vaultLocked_throws() async {
        mockCrypto._isUnlocked = false
        do {
            try await sut.enableBiometricUnlock()
            XCTFail("Expected biometricUnavailable")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricUnavailable)
        }
    }

    func testEnableBiometricUnlock_vaultUnlocked_writesKeychain() async throws {
        mockCrypto._isUnlocked = true
        try await sut.enableBiometricUnlock()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "biometricUnlockEnabled"))
        // Verify the biometric keychain has a 64-byte item.
        let key = KeychainKey.biometricVaultKey(testUserId)
        let data = try await mockBiometricKeychain.readBiometric(key: key)
        XCTAssertEqual(data.count, 64)
    }

    // MARK: - disableBiometricUnlock

    func testDisableBiometricUnlock_clearsPreferenceAndKeychain() async throws {
        // Enable first.
        mockCrypto._isUnlocked = true
        try await sut.enableBiometricUnlock()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "biometricUnlockEnabled"))

        try await sut.disableBiometricUnlock()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "biometricUnlockEnabled"))
        // Keychain item should be gone.
        let key = KeychainKey.biometricVaultKey(testUserId)
        do {
            _ = try await mockBiometricKeychain.readBiometric(key: key)
            XCTFail("Expected itemNotFound")
        } catch {
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    // MARK: - unlockWithBiometrics

    func testUnlockWithBiometrics_success_returnsAccount() async throws {
        // Seed a biometric key.
        let keys = CryptoKeys(encryptionKey: Data(count: 32), macKey: Data(count: 32))
        try mockBiometricKeychain.writeBiometric(
            data: keys.toData(),
            key: KeychainKey.biometricVaultKey(testUserId)
        )

        let account = try await sut.unlockWithBiometrics()
        XCTAssertEqual(account.email, testEmail)
    }

    func testUnlockWithBiometrics_itemNotFound_throwsInvalidated() async {
        // No biometric key in keychain.
        do {
            _ = try await sut.unlockWithBiometrics()
            XCTFail("Expected biometricInvalidated")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricInvalidated)
            XCTAssertFalse(UserDefaults.standard.bool(forKey: "biometricUnlockEnabled"))
            XCTAssertFalse(UserDefaults.standard.bool(forKey: "biometricEnrollmentPromptShown"))
        }
    }

    // MARK: - signOut clears biometric

    func testSignOut_deletesBiometricKeychainItem() async throws {
        mockCrypto._isUnlocked = true
        try await sut.enableBiometricUnlock()
        try await sut.signOut()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "biometricUnlockEnabled"))
    }

    // MARK: - Helpers

    private func seedStoredSession() {
        mockKeychain.seed(key: "bw.macos:activeUserId", value: testUserId)
        mockKeychain.seed(key: "bw.macos:\(testUserId):email", value: testEmail)
        let env = try! JSONEncoder().encode(testEnv)
        mockKeychain.seed(key: "bw.macos:\(testUserId):serverEnvironment", data: env)
        mockKeychain.seed(key: "bw.macos:\(testUserId):accessToken", value: "token")
        mockKeychain.seed(key: "bw.macos:\(testUserId):refreshToken", value: "refresh")
    }
}
