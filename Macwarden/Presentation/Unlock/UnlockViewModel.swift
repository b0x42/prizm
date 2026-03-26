import Combine
import Foundation
import os.log

// MARK: - UnlockFlowState

enum UnlockFlowState: Equatable {
    case unlock
    case loading
    case syncing(message: String)
    case vault
    /// Returned to login (triggered by "Sign in with a different account").
    case login
}

// MARK: - UnlockViewModel

/// ViewModel for the vault unlock screen (User Story 2).
///
/// The user has a stored session; this screen re-derives the vault key from the
/// master password locally (no network call) then re-syncs the vault.
@MainActor
final class UnlockViewModel: ObservableObject {

    // MARK: - Published state

    @Published var password:      String = ""
    @Published var errorMessage:  String?
    @Published private(set) var flowState: UnlockFlowState = .unlock

    // MARK: - Dependencies

    private let auth:    any AuthRepository
    private let sync:    any SyncUseCase
    private let account: Account   // Pre-loaded from storedAccount()
    private let logger = Logger(subsystem: "com.macwarden", category: "UnlockViewModel")

    // MARK: - Init

    init(auth: any AuthRepository, sync: any SyncUseCase, account: Account) {
        self.auth    = auth
        self.sync    = sync
        self.account = account
    }

    // MARK: - Derived properties

    /// The stored email, shown read-only in the UI (FR-003).
    var email: String { account.email }

    // MARK: - Actions

    func unlock() {
        logger.info("Unlock flow started")
        errorMessage = nil
        flowState    = .loading

        // Convert the password String to Data at this boundary so the KDF stack
        // receives `Data` that can be zeroed after use (Constitution §III).
        guard let passwordData = password.data(using: .utf8) else {
            errorMessage = "Invalid password encoding."
            flowState    = .unlock
            return
        }

        Task {
            do {
                _ = try await auth.unlockWithPassword(passwordData)
                // Clear the password field after a successful unlock so the plaintext
                // does not linger in the published property.
                password = ""
                await performSync()
            } catch let err as AuthError {
                logger.error("Unlock failed: \(err.localizedDescription, privacy: .public)")
                errorMessage = err.errorDescription
                flowState    = .unlock
            } catch {
                logger.error("Unlock failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                flowState    = .unlock
            }
        }
    }

    /// Clears session and returns to the login screen (FR-039).
    func signInWithDifferentAccount() {
        logger.info("User switching to different account")
        Task {
            do {
                try await auth.signOut()
            } catch {
                logger.error("Sign-out failed: \(error.localizedDescription, privacy: .public)")
            }
            flowState = .login
        }
    }

    // MARK: - Private

    private func performSync() async {
        flowState = .syncing(message: "Preparing…")
        do {
            _ = try await sync.execute(progress: { [weak self] message in
                Task { @MainActor [weak self] in self?.flowState = .syncing(message: message) }
            })
            flowState = .vault
        } catch {
            logger.error("Post-unlock sync failed (non-fatal): \(error.localizedDescription, privacy: .public)")
            flowState = .vault
        }
    }
}
