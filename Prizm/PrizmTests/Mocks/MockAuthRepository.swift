import Foundation
@testable import Prizm

/// Test double for `AuthRepository` — used by `LoginUseCaseTests`.
final class MockAuthRepository: AuthRepository {

    // MARK: - State observations

    private(set) var setServerEnvironmentCalled:   Bool = false
    private(set) var loginWithPasswordCalled:      Bool = false
    private(set) var unlockWithPasswordCalled:     Bool = false
    private(set) var cancelTwoFactorCalled:        Bool = false
    private(set) var signOutCalled:                Bool = false
    var             lockVaultCalledCount:           Int  = 0

    // MARK: - Stubs

    /// When non-nil, `validateServerURL` throws this error.
    var validateServerURLError: AuthError?

    /// Result returned by `loginWithPassword` and used by `unlockWithPassword`.
    var stubbedLoginResult: LoginResult = .success(
        Account(
            userId:            "stub-user",
            email:             "stub@example.com",
            name:              nil,
            serverEnvironment: ServerEnvironment(
                base:      URL(string: "https://stub.example.com")!,
                overrides: nil
            )
        )
    )

    /// When non-nil, `loginWithPassword` throws this error instead of returning a result.
    var loginWithPasswordError: Error?

    /// When non-nil, `unlockWithPassword` throws this error.
    var unlockWithPasswordError: Error?

    // MARK: - AuthRepository

    var serverEnvironment: ServerEnvironment?

    func validateServerURL(_ urlString: String) throws {
        if let err = validateServerURLError { throw err }
    }

    func setServerEnvironment(_ environment: ServerEnvironment) async throws {
        serverEnvironment            = environment
        setServerEnvironmentCalled   = true
    }

    func loginWithPassword(email: String, masterPassword: Data) async throws -> LoginResult {
        loginWithPasswordCalled = true
        if let err = loginWithPasswordError { throw err }
        return stubbedLoginResult
    }

    func loginWithTOTP(code: String, rememberDevice: Bool) async throws -> Account {
        guard case .success(let account) = stubbedLoginResult else {
            throw AuthError.invalidTwoFactorCode
        }
        return account
    }

    func cancelTwoFactor() {
        cancelTwoFactorCalled = true
    }

    func unlockWithPassword(_ masterPassword: Data) async throws -> Account {
        unlockWithPasswordCalled = true
        if let err = unlockWithPasswordError { throw err }
        guard case .success(let account) = stubbedLoginResult else {
            throw AuthError.invalidCredentials
        }
        return account
    }

    func storedAccount() -> Account? { stubbedStoredAccount }

    /// Stub for `storedAccount()`. Defaults to nil.
    var stubbedStoredAccount: Account?

    func signOut() async throws {
        signOutCalled = true
    }

    func lockVault() async {
        lockVaultCalledCount += 1
    }

    // MARK: - Biometric unlock

    var stubbedDeviceBiometricCapable: Bool = false
    var stubbedBiometricUnlockAvailable: Bool = false
    private(set) var enableBiometricUnlockCalled: Bool = false
    private(set) var disableBiometricUnlockCalled: Bool = false
    private(set) var unlockWithBiometricsCalled: Bool = false
    private(set) var unlockWithBiometricsCallCount: Int = 0
    var enableBiometricUnlockError: Error?
    var unlockWithBiometricsError: Error?

    var deviceBiometricCapable: Bool { stubbedDeviceBiometricCapable }
    var biometricUnlockAvailable: Bool { stubbedBiometricUnlockAvailable }

    func enableBiometricUnlock() async throws {
        enableBiometricUnlockCalled = true
        if let err = enableBiometricUnlockError { throw err }
    }

    func disableBiometricUnlock() async throws {
        disableBiometricUnlockCalled = true
    }

    func unlockWithBiometrics() async throws -> Account {
        unlockWithBiometricsCalled = true
        unlockWithBiometricsCallCount += 1
        if let err = unlockWithBiometricsError { throw err }
        guard case .success(let account) = stubbedLoginResult else {
            throw AuthError.biometricUnavailable
        }
        return account
    }
}
