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
    case vault(Account)
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
    @Published private(set) var flowState: LoginFlowState = .login {
        didSet { onFlowStateChange?(flowState) }
    }

    // MARK: - Root callback

    /// Set by `AppRootViewModel` to observe flow completion.
    var onFlowStateChange: ((LoginFlowState) -> Void)?

    // MARK: - Dependencies

    private let auth: any AuthRepository
    private let sync: any SyncUseCase
    private let logger = Logger(subsystem: "com.bitwarden-macos", category: "LoginViewModel")

    // MARK: - Init

    init(auth: any AuthRepository, sync: any SyncUseCase) {
        self.auth = auth
        self.sync = sync
    }

    // MARK: - Actions

    /// Validates credentials and initiates the login sequence.
    func signIn() {
        logger.info("Sign-in flow started")
        errorMessage = nil
        flowState    = .loading

        Task {
            do {
                // Validate + configure server URL.
                try auth.validateServerURL(serverURL)
                let trimmed = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
                guard let url = URL(string: trimmed) else { throw AuthError.invalidURL }
                try await auth.setServerEnvironment(ServerEnvironment(base: url, overrides: nil))

                // Attempt password login.
                let result = try await auth.loginWithPassword(
                    email:          email,
                    masterPassword: password
                )

                switch result {
                case .success(let account):
                    await performSync(account: account)

                case .requiresTwoFactor(let method):
                    guard case .authenticatorApp = method else {
                        if case .unsupported(let name) = method {
                            throw AuthError.unsupported2FAMethod(name)
                        }
                        throw AuthError.invalidCredentials
                    }
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

    /// Completes a pending TOTP 2FA challenge.
    func submitTOTP(code: String, rememberDevice: Bool) {
        logger.info("TOTP submission started")
        errorMessage = nil
        flowState    = .loading

        Task {
            do {
                let account = try await auth.loginWithTOTP(code: code, rememberDevice: rememberDevice)
                await performSync(account: account)
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

    // MARK: - Private helpers

    private func performSync(account: Account) async {
        flowState = .syncing(message: "Preparing…")
        do {
            _ = try await sync.execute(progress: { [weak self] message in
                // Progress is called from SyncRepositoryImpl's actor thread;
                // dispatch to @MainActor to update @Published flowState.
                Task { @MainActor [weak self] in self?.flowState = .syncing(message: message) }
            })
            flowState = .vault(account)
        } catch {
            // Sync failure is non-fatal for Phase 4 — show vault with whatever was synced.
            // A banner error would be surfaced in Phase 6 (FR-049).
            flowState = .vault(account)
        }
    }
}
