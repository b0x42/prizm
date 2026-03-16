import Foundation

// MARK: - UnlockFlowState

enum UnlockFlowState: Equatable {
    case unlock
    case loading
    case syncing(message: String)
    case vault(Account)
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
    @Published private(set) var flowState: UnlockFlowState = .unlock {
        didSet { onFlowStateChange?(flowState) }
    }

    // MARK: - Root callback

    /// Set by `AppRootViewModel` to observe flow completion.
    var onFlowStateChange: ((UnlockFlowState) -> Void)?

    // MARK: - Dependencies

    private let auth:    any AuthRepository
    private let sync:    any SyncUseCase
    private let account: Account   // Pre-loaded from storedAccount()

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
        errorMessage = nil
        flowState    = .loading

        Task {
            do {
                _ = try await auth.unlockWithPassword(password)
                await performSync()
            } catch let err as AuthError {
                errorMessage = err.errorDescription
                flowState    = .unlock
            } catch {
                errorMessage = error.localizedDescription
                flowState    = .unlock
            }
        }
    }

    /// Clears session and returns to the login screen (FR-039).
    func signInWithDifferentAccount() {
        Task {
            try? await auth.signOut()
            flowState = .login
        }
    }

    // MARK: - Private

    private func performSync() async {
        flowState = .syncing(message: "Preparing…")
        do {
            _ = try await sync.execute(progress: { [weak self] message in
                self?.flowState = .syncing(message: message)
            })
            flowState = .vault(account)
        } catch {
            // Non-fatal: show vault with empty store; error banner in Phase 6.
            flowState = .vault(account)
        }
    }
}
