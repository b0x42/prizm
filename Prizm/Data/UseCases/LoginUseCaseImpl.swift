import Foundation
import os.log

// MARK: - LoginUseCaseImpl

/// Orchestrates the full account login flow:
///   1. Build `ServerEnvironment` from caller-supplied `serverType` + `serverURL`.
///   2. Validate URL (self-hosted only) and set environment on `AuthRepository`.
///   3. Call `AuthRepository.loginWithPassword`.
///   4. If `.success`: call `SyncRepository.sync` to populate the vault.
///   5. If `.requiresTwoFactor`: return immediately — sync is deferred to after TOTP.
///   6. If `.requiresNewDeviceOTP`: return immediately — sync deferred to after OTP.
///
/// `SyncRepository.sync` is called here (not inside `AuthRepository`) to keep the
/// Domain layer orchestration visible and testable at the use-case level.
final class LoginUseCaseImpl: LoginUseCase {

    private let auth: any AuthRepository
    private let sync: any SyncRepository

    private let logger = Logger(subsystem: "com.prizm", category: "LoginUseCase")

    init(auth: any AuthRepository, sync: any SyncRepository) {
        self.auth = auth
        self.sync = sync
    }

    func execute(serverType: ServerType, serverURL: String, email: String, masterPassword: Data) async throws -> LoginResult {
        let environment = try buildEnvironment(serverType: serverType, serverURL: serverURL)
        // Validate self-hosted URL against HTTPS scheme and host presence (Constitution §III).
        // Cloud URLs are hardcoded constants and never need validation.
        if serverType == .selfHosted {
            try auth.validateServerURL(environment.base.absoluteString)
        }

        try await auth.setServerEnvironment(environment)

        logger.info("Attempting login for \(email, privacy: .private)")
        let result = try await auth.loginWithPassword(email: email, masterPassword: masterPassword)

        switch result {
        case .success:
            // Sync vault immediately after successful login.
            // Sync is best-effort: a degraded server should not prevent vault access.
            logger.info("Login succeeded — starting vault sync")
            do {
                _ = try await sync.sync(progress: { _ in })
            } catch {
                logger.error("Post-login sync failed (non-fatal): \(error.localizedDescription, privacy: .public)")
            }
            return result

        case .requiresTwoFactor:
            // Sync deferred until TOTP accepted — no access token yet.
            logger.info("Login requires 2FA")
            return result

        case .requiresNewDeviceOTP:
            // Sync deferred until OTP accepted — no access token yet.
            logger.info("Login requires new-device OTP")
            return result
        }
    }

    func completeTOTP(code: String, rememberDevice: Bool) async throws -> Account {
        logger.info("Completing TOTP")
        let account = try await auth.loginWithTOTP(code: code, rememberDevice: rememberDevice)
        do {
            _ = try await sync.sync(progress: { _ in })
        } catch {
            logger.error("Post-TOTP sync failed (non-fatal): \(error.localizedDescription, privacy: .public)")
        }
        return account
    }

    func cancelTOTP() {
        auth.cancelTwoFactor()
    }

    func completeNewDeviceOTP(otp: String) async throws -> Account {
        logger.info("Completing new-device OTP")
        let account = try await auth.loginWithNewDeviceOTP(otp)
        do {
            _ = try await sync.sync(progress: { _ in })
        } catch {
            logger.error("Post-OTP sync failed (non-fatal): \(error.localizedDescription, privacy: .public)")
        }
        return account
    }

    func resendNewDeviceOTP() async throws {
        logger.info("Resending new-device OTP")
        try await auth.requestNewDeviceOTP()
    }

    func cancelNewDeviceOTP() {
        auth.cancelNewDeviceOTP()
    }

    // MARK: - Private helpers

    private func buildEnvironment(serverType: ServerType, serverURL: String) throws -> ServerEnvironment {
        switch serverType {
        case .cloudUS:
            return .cloudUS()
        case .cloudEU:
            return .cloudEU()
        case .selfHosted:
            let trimmed = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
            guard !trimmed.isEmpty, let base = URL(string: trimmed) else {
                throw AuthError.invalidURL
            }
            return ServerEnvironment(base: base, overrides: nil)
        }
    }
}
