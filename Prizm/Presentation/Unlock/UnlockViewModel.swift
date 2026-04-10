import Combine
import Foundation
import LocalAuthentication
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
    @Published var showEnrollmentPrompt: Bool = false
    @Published private(set) var enrollmentReason: EnrollmentReason = .firstTime

    // MARK: - Dependencies

    private let auth:    any AuthRepository
    private let sync:    any SyncUseCase
    private let account: Account   // Pre-loaded from storedAccount()
    private let logger = Logger(subsystem: "com.prizm", category: "UnlockViewModel")

    /// Tracks whether the last biometric attempt failed with invalidation,
    /// so the enrollment prompt can show the re-enroll copy.
    private var lastBiometricInvalidated = false

    // MARK: - Init

    init(auth: any AuthRepository, sync: any SyncUseCase, account: Account) {
        self.auth    = auth
        self.sync    = sync
        self.account = account
    }

    // MARK: - Derived properties

    /// The stored email, shown read-only in the UI (FR-003).
    var email: String { account.email }

    /// Whether biometric unlock is available for this device and session.
    var biometricUnlockAvailable: Bool { auth.biometricUnlockAvailable }

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
                await checkEnrollmentOrSync()
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

    /// Attempts biometric unlock. On success, proceeds to sync.
    /// On cancellation, falls back silently to the password field.
    /// On lockout, shows an error. On invalidation, shows the invalidation message.
    func unlockWithBiometrics() {
        Task {
            do {
                _ = try await auth.unlockWithBiometrics()
                lastBiometricInvalidated = false
                await checkEnrollmentOrSync()
            } catch let err as AuthError where err == .biometricInvalidated {
                lastBiometricInvalidated = true
                errorMessage = err.errorDescription
                flowState = .unlock
            } catch let err as NSError
                where err.domain == NSOSStatusErrorDomain && err.code == Int(errSecUserCanceled) {
                // User cancelled — no error shown, password field stays focused.
                flowState = .unlock
            } catch {
                // Lockout or other failure — show the error.
                errorMessage = error.localizedDescription
                flowState = .unlock
            }
        }
    }

    /// Triggers biometric unlock if available; no-op otherwise.
    func triggerBiometricUnlockIfAvailable() {
        guard biometricUnlockAvailable else { return }
        unlockWithBiometrics()
    }

    /// Called when the user accepts the enrollment prompt.
    func confirmEnrollBiometric() {
        Task {
            do {
                try await auth.enableBiometricUnlock()
            } catch {
                logger.error("Enable biometric unlock failed: \(error.localizedDescription, privacy: .public)")
            }
            UserDefaults.standard.set(true, forKey: "biometricEnrollmentPromptShown")
            showEnrollmentPrompt = false
            await performSync()
        }
    }

    /// Called when the user dismisses the enrollment prompt without enabling.
    func dismissEnrollmentPrompt() {
        UserDefaults.standard.set(true, forKey: "biometricEnrollmentPromptShown")
        showEnrollmentPrompt = false
        Task { await performSync() }
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

    /// After a successful password unlock, checks whether to show the enrollment prompt
    /// before proceeding to sync (design Decision 7).
    private func checkEnrollmentOrSync() async {
        let biometricsAvailable = LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: nil
        )
        let alreadyEnabled = UserDefaults.standard.bool(forKey: "biometricUnlockEnabled")
        let promptShown    = UserDefaults.standard.bool(forKey: "biometricEnrollmentPromptShown")

        if biometricsAvailable && !alreadyEnabled && !promptShown {
            enrollmentReason = lastBiometricInvalidated ? .reEnrollAfterInvalidation : .firstTime
            showEnrollmentPrompt = true
            // performSync() will be called by confirmEnrollBiometric() or dismissEnrollmentPrompt().
            return
        }
        await performSync()
    }

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