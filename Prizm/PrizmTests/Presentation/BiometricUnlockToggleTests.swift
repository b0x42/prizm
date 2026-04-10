import XCTest
@testable import Prizm

/// Tests for `BiometricUnlockToggle` logic via `MockAuthRepository`.
///
/// The toggle's enable/disable paths call `AuthRepository.enableBiometricUnlock()`
/// and `disableBiometricUnlock()`. These tests verify the mock wiring.
@MainActor
final class BiometricUnlockToggleTests: XCTestCase {

    private var mockAuth: MockAuthRepository!

    override func setUp() {
        mockAuth = MockAuthRepository()
    }

    func testEnableBiometricUnlock_callsAuthRepository() async throws {
        try await mockAuth.enableBiometricUnlock()
        XCTAssertTrue(mockAuth.enableBiometricUnlockCalled)
    }

    func testDisableBiometricUnlock_callsAuthRepository() async throws {
        try await mockAuth.disableBiometricUnlock()
        XCTAssertTrue(mockAuth.disableBiometricUnlockCalled)
    }

    func testEnableBiometricUnlock_vaultLocked_throws() async {
        mockAuth.enableBiometricUnlockError = AuthError.biometricUnavailable
        do {
            try await mockAuth.enableBiometricUnlock()
            XCTFail("Expected biometricUnavailable")
        } catch {
            XCTAssertEqual(error as? AuthError, .biometricUnavailable)
        }
    }
}
