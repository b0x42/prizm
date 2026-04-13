import LocalAuthentication
import Foundation

/// Data-layer protocol for biometric unlock driven by `LAAuthenticationView`.
///
/// Separating this from `AuthRepository` (Domain layer) keeps `LAContext` — a
/// LocalAuthentication type — out of the Domain layer (Constitution §II).
/// `AuthRepositoryImpl` conforms; `UnlockViewModel` consumes it optionally so
/// tests without biometric hardware continue to work without a mock.
protocol EmbeddedBiometricUnlock: AnyObject {
    /// Evaluates biometric policy on `context` then reads the vault key from
    /// the biometric Keychain item and unlocks the vault.
    ///
    /// If `LAAuthenticationView` was paired with `context` and is visible in the
    /// window before this call, `evaluatePolicy` routes its UI through that view —
    /// no system modal dialog appears. This is the inline Touch ID experience.
    ///
    /// - Parameter context: The same `LAContext` instance passed to
    ///   `EmbeddedTouchIDView`. Must not have been previously evaluated.
    /// - Returns: The unlocked `Account`.
    /// - Throws: `AuthError.biometricInvalidated` if the Keychain item is gone.
    func unlockWithBiometrics(context: LAContext) async throws -> Account
}
