import Combine
import Foundation
import os.log

// MARK: - LoginFlowState

/// State machine driving the root view transition.
enum LoginFlowState: Equatable {
    case login
    case loading
    case totpPrompt
    case otpPrompt
    case syncing(message: String)
    case vault
}

// MARK: - LoginViewModel

/// ViewModel for the login + 2FA + new-device OTP + sync flow (User Story 1).
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - Published state

    @Published var serverURL:    String = ""
    @Published var email:        String = ""
    @Published var password:     String = ""
    @Published var errorMessage: String?
    @Published private(set) var flowState: LoginFlowState = .login

    @Published var serverType: ServerType = .cloudUS {
        didSet {
            UserDefaults.standard.set(serverType.rawValue, forKey: Keys.lastServerType)
        }
    }

    @Published var otpCode: String = ""

    // MARK: - Dependencies

    private let loginUseCase: any LoginUseCase
    private let logger = Logger(subsystem: "com.prizm", category: "LoginViewModel")

    private enum Keys {
        static let lastServerType = "com.prizm.login.lastServerType"
        static let lastServerURL  = "com.prizm.login.lastServerURL"
    }

    // MARK: - Init

    init(loginUseCase: any LoginUseCase) {
        self.loginUseCase = loginUseCase
        // Restore persisted server type (defaults to cloudUS on fresh install).
        if let raw  = UserDefaults.standard.string(forKey: Keys.lastServerType),
           let type = ServerType(rawValue: raw) {
            serverType = type
        }
        // Restore last entered self-hosted URL.
        serverURL = UserDefaults.standard.string(forKey: Keys.lastServerURL) ?? ""
    }

    // MARK: - Computed state

    /// True while an async operation is in flight. Use to disable secondary controls (Resend, Cancel).
    var isLoading: Bool {
        if case .loading = flowState { return true }
        return false
    }

    var isSignInDisabled: Bool {
        switch flowState {
        case .loading:
            return true
        case .otpPrompt:
            return otpCode.isEmpty
        default:
            break
        }
        switch serverType {
        case .cloudUS, .cloudEU:
            return email.isEmpty || password.isEmpty
        case .selfHosted:
            return serverURL.isEmpty || email.isEmpty || password.isEmpty
        }
    }

    // MARK: - Actions

    /// Validates credentials and initiates the login sequence.
    func signIn() {
        logger.info("Sign-in flow started")
        errorMessage = nil
        flowState    = .loading

        guard let passwordData = password.data(using: .utf8), !passwordData.isEmpty else {
            errorMessage = "Invalid password encoding."
            flowState    = .login
            return
        }

        // Persist server URL changes when the user is on self-hosted.
        if serverType == .selfHosted {
            UserDefaults.standard.set(serverURL, forKey: Keys.lastServerURL)
        }

        Task {
            do {
                let result = try await loginUseCase.execute(
                    serverType:     serverType,
                    serverURL:      serverURL,
                    email:          email,
                    masterPassword: passwordData
                )

                switch result {
                case .success:
                    password  = ""
                    flowState = .vault

                case .requiresTwoFactor(let method):
                    guard case .authenticatorApp = method else {
                        if case .unsupported(let name) = method {
                            throw AuthError.unsupported2FAMethod(name)
                        }
                        throw AuthError.invalidCredentials
                    }
                    password  = ""
                    flowState = .totpPrompt

                case .requiresNewDeviceOTP:
                    password  = ""
                    flowState = .otpPrompt
                }

            } catch let err as AuthError {
                logger.error("Sign-in failed: \(err.localizedDescription, privacy: .public)")
                errorMessage = err.errorDescription
                flowState    = .login
                postAnnouncement(err.errorDescription ?? err.localizedDescription)
            } catch {
                logger.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                flowState    = .login
                postAnnouncement(error.localizedDescription)
            }
        }
    }

    /// Cancels the pending TOTP challenge and returns to the login screen.
    func cancelTOTP() {
        loginUseCase.cancelTOTP()
        flowState = .login
    }

    /// Completes a pending TOTP 2FA challenge.
    func submitTOTP(code: String, rememberDevice: Bool) {
        logger.info("TOTP submission started")
        errorMessage = nil
        flowState    = .loading

        Task {
            do {
                let _ = try await loginUseCase.completeTOTP(code: code, rememberDevice: rememberDevice)
                flowState = .vault
            } catch let err as AuthError {
                logger.error("TOTP submission failed: \(err.localizedDescription, privacy: .public)")
                errorMessage = err.errorDescription
                flowState    = .totpPrompt
                postAnnouncement(err.errorDescription ?? err.localizedDescription)
            } catch {
                logger.error("TOTP submission failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                flowState    = .totpPrompt
                postAnnouncement(error.localizedDescription)
            }
        }
    }

    /// Submits the new-device OTP.
    func submitOTP() {
        logger.info("OTP submission started")
        errorMessage = nil
        flowState    = .loading
        // Clear OTP immediately so it doesn't linger in the state graph (Constitution §III).
        let otp = otpCode
        otpCode = ""

        Task {
            do {
                _ = try await loginUseCase.completeNewDeviceOTP(otp: otp)
                flowState = .vault
            } catch let err as AuthError {
                logger.error("OTP submission failed: \(err.localizedDescription, privacy: .public)")
                errorMessage = err.errorDescription
                flowState    = .otpPrompt
                postAnnouncement(err.errorDescription ?? err.localizedDescription)
            } catch {
                logger.error("OTP submission failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                flowState    = .otpPrompt
                postAnnouncement(error.localizedDescription)
            }
        }
    }

    /// Re-sends the new-device OTP email.
    func resendOTP() {
        logger.info("Resending OTP")
        errorMessage = nil
        flowState    = .loading

        Task {
            do {
                try await loginUseCase.resendNewDeviceOTP()
                flowState = .otpPrompt
                otpCode   = ""
                let msg = "A new code has been sent to your email."
                postAnnouncement(msg)
                logger.info("OTP resend succeeded")
            } catch let err as AuthError {
                logger.error("OTP resend failed: \(err.localizedDescription, privacy: .public)")
                flowState    = .otpPrompt
                errorMessage = err.errorDescription
                postAnnouncement(err.errorDescription ?? err.localizedDescription)
            } catch {
                logger.error("OTP resend failed: \(error.localizedDescription, privacy: .public)")
                flowState    = .otpPrompt
                errorMessage = error.localizedDescription
                postAnnouncement(error.localizedDescription)
            }
        }
    }

    /// Cancels the new-device OTP challenge and returns to the login screen.
    func cancelOTP() {
        loginUseCase.cancelNewDeviceOTP()
        flowState = .login
    }

    // MARK: - Private helpers

    private func postAnnouncement(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
