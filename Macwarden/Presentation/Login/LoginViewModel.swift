import Combine
import Foundation
import os.log

// MARK: - LoginFlowState

/// State machine driving the root view transition.
enum LoginFlowState: Equatable {
    case login
    case loading
    case totpPrompt
    case syncing(message: String)
    case vault
}

// MARK: - LoginViewModel

/// ViewModel for the login + 2FA + sync flow (User Story 1).
///
/// The Presentation layer uses the Domain protocols directly (`AuthRepository`, `SyncUseCase`)
/// so it can report per-step progress to the UI.  No Data-layer types are imported here.
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - Published state

    @Published var serverURL:    String = ""
    @Published var email:        String = ""
    @Published var password:     String = ""
    @Published var errorMessage: String?
    @Published private(set) var flowState: LoginFlowState = .login

    // MARK: - Dependencies

    private let loginUseCase: any LoginUseCase
    private let logger = Logger(subsystem: "com.macwarden", category: "LoginViewModel")

    // MARK: - Init

    init(loginUseCase: any LoginUseCase) {
        self.loginUseCase = loginUseCase
    }

    // MARK: - Actions

    /// Validates credentials and initiates the login sequence.
    func signIn() {
        logger.info("Sign-in flow started")
        errorMessage = nil
        flowState    = .loading

        // Convert the password String to Data at this boundary — the only place the
        // String-to-bytes conversion happens. `Data` can be zeroed after the KDF call;
        // `String` cannot (Constitution §III).
        // Reject empty password here to match the UI's disabled-button guard.
        // The Task below must never be spawned with an empty credential.
        guard let passwordData = password.data(using: .utf8), !passwordData.isEmpty else {
            errorMessage = "Invalid password encoding."
            flowState    = .login
            return
        }

        Task {
            do {
                let result = try await loginUseCase.execute(
                    serverURL:      serverURL,
                    email:          email,
                    masterPassword: passwordData
                )

                switch result {
                case .success:
                    // Clear the password field so the plaintext does not linger in
                    // the published property (and therefore the SwiftUI state graph).
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
                }

            } catch let err as AuthError {
                logger.error("Sign-in failed: \(err.localizedDescription, privacy: .public)")
                errorMessage = err.errorDescription
                flowState    = .login
            } catch {
                logger.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                flowState    = .login
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
            } catch {
                logger.error("TOTP submission failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                flowState    = .totpPrompt
            }
        }
    }
}
