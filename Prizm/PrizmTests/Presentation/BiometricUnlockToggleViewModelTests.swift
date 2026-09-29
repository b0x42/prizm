import XCTest
@testable import Prizm

/// Tests for `BiometricUnlockToggleViewModel` — covers the `settings-screen` spec
/// requirement "Biometric unlock toggle is disabled only while the vault is actually
/// locked" (#67: the toggle used to latch disabled forever after one vault-locked
/// failure, with no way to recover short of relaunching the app).
@MainActor
final class BiometricUnlockToggleViewModelTests: XCTestCase {

    private var mockAuth: MockAuthRepository!
    private var sut: BiometricUnlockToggleViewModel!

    override func setUp() async throws {
        mockAuth = MockAuthRepository()
        sut = BiometricUnlockToggleViewModel(authRepository: mockAuth)
    }

    /// Existing scenario: toggle attempt fails while the vault is locked — disables the
    /// toggle and shows the hint. Must keep passing unchanged after the extraction.
    func testToggle_vaultLocked_disablesToggleAndShowsHint() async {
        mockAuth.enableBiometricUnlockError = AuthError.biometricUnavailable

        await sut.toggleBiometric(enabled: true)

        XCTAssertTrue(sut.showVaultLockedHint)
        XCTAssertTrue(sut.isToggleDisabled)
        XCTAssertFalse(sut.isEnabled, "isEnabled should revert to false on failure")
    }

    /// New scenario: once the vault is unlocked again, the toggle must re-enable itself
    /// without requiring the Settings window to be closed and reopened.
    func testVaultDidUnlock_afterVaultLockedFailure_reenablesToggle() async {
        mockAuth.enableBiometricUnlockError = AuthError.biometricUnavailable
        await sut.toggleBiometric(enabled: true)
        XCTAssertTrue(sut.showVaultLockedHint, "precondition: toggle should be disabled with the hint shown")

        NotificationCenter.default.post(name: .vaultDidUnlock, object: nil)
        // The observer dispatches onto the main queue; drain it before asserting.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertFalse(sut.showVaultLockedHint, "toggle should re-enable after the vault is unlocked")
        XCTAssertFalse(sut.isToggleDisabled)
    }

    /// A successful toggle retry also clears the hint (unchanged behavior).
    func testToggle_successfulRetry_clearsHint() async {
        mockAuth.enableBiometricUnlockError = AuthError.biometricUnavailable
        await sut.toggleBiometric(enabled: true)
        XCTAssertTrue(sut.showVaultLockedHint)

        mockAuth.enableBiometricUnlockError = nil
        await sut.toggleBiometric(enabled: true)

        XCTAssertFalse(sut.showVaultLockedHint)
    }
}
