import XCTest
@testable import Prizm

/// Verifies that `MockAuthRepository` satisfies the biometric extension of `AuthRepository`.
@MainActor
final class AuthRepositoryBiometricTests: XCTestCase {

    private var sut: MockAuthRepository!

    override func setUp() {
        sut = MockAuthRepository()
    }

    func testBiometricUnlockAvailableDefaultsFalse() {
        XCTAssertFalse(sut.biometricUnlockAvailable)
    }

    func testBiometricUnlockAvailableReflectsStub() {
        sut.stubbedBiometricUnlockAvailable = true
        XCTAssertTrue(sut.biometricUnlockAvailable)
    }

    func testEnableBiometricUnlockRecordsCall() async throws {
        try await sut.enableBiometricUnlock()
        XCTAssertTrue(sut.enableBiometricUnlockCalled)
    }

    func testEnableBiometricUnlockThrowsWhenStubbed() async {
        sut.enableBiometricUnlockError = AuthError.biometricUnavailable
        do {
            try await sut.enableBiometricUnlock()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricUnavailable)
        }
    }

    func testDisableBiometricUnlockRecordsCall() async throws {
        try await sut.disableBiometricUnlock()
        XCTAssertTrue(sut.disableBiometricUnlockCalled)
    }

    func testUnlockWithBiometricsReturnsAccount() async throws {
        let account = try await sut.unlockWithBiometrics()
        XCTAssertTrue(sut.unlockWithBiometricsCalled)
        XCTAssertEqual(account.email, "stub@example.com")
    }

    func testUnlockWithBiometricsThrowsInvalidated() async {
        sut.unlockWithBiometricsError = AuthError.biometricInvalidated
        do {
            _ = try await sut.unlockWithBiometrics()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricInvalidated)
        }
    }
}
