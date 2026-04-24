import Foundation

/// Orchestrates the full account login flow:
/// `execute` → (optional) `completeNewDeviceOTP` or `completeTOTP` → sync.
///
/// The caller is responsible for constructing the correct `ServerEnvironment` before calling
/// `execute`. On a new-device OTP challenge, the flow is:
///   1. `execute(environment:email:masterPassword:)` → `.requiresNewDeviceOTP`
///   2. User enters the OTP received by email
///   3. `completeNewDeviceOTP(otp:)` → Account (triggers vault sync)
///
/// On a TOTP 2FA challenge, the flow is:
///   1. `execute(environment:email:masterPassword:)` → `.requiresTwoFactor`
///   2. User enters the authenticator code
///   3. `completeTOTP(code:rememberDevice:)` → Account (triggers vault sync)
protocol LoginUseCase {
    func execute(
        environment:    ServerEnvironment,
        email:          String,
        masterPassword: Data
    ) async throws -> LoginResult

    func completeTOTP(code: String, rememberDevice: Bool) async throws -> Account

    /// Cancels a pending TOTP challenge and clears in-memory key material held from
    /// the initial password-login step (see `AuthRepository.cancelTwoFactor`).
    func cancelTOTP()

    /// Retries the identity token request with the new-device OTP the user received by email.
    /// Only valid to call after `execute` returns `LoginResult.requiresNewDeviceOTP`.
    /// On success, triggers vault sync and returns the logged-in `Account`.
    func completeNewDeviceOTP(otp: String) async throws -> Account

    /// Re-triggers the original identity token request without an OTP, causing the server to
    /// dispatch a new verification code to the user's registered email.
    /// Only valid when in the OTP challenge state.
    func resendNewDeviceOTP() async throws

    /// Cancels a pending new-device OTP challenge and clears any cached credentials.
    func cancelNewDeviceOTP()
}
