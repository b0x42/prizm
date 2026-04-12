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
    /// Enrollment offer shown inline on the unlock screen after first successful
    /// password unlock (design Decision 3). Replaces the former `.sheet` approach.
    case enrollmentPrompt(reason: EnrollmentReason)
}

// MARK: - UnlockViewModel

/// ViewModel for the vault unlock screen (User Story 2).
///
/// The user has a stored session; this screen re-derives the vault key from the
/// master password locally (no network call) then re-syncs the vault.
@MainActor
final class UnlockViewModel: ObservableObject {

    // MARK: - Published state

    @Published var password:     String = ""
    @Published var errorMessage: String?
    @Published private(set) var flowState: UnlockFlowState = .unlock

    // MARK: - Dependencies

    private let auth:             any AuthRepository
    private let sync:             any SyncUseCase
    private let account:          Account
    private let embeddedBiometric: (any EmbeddedBiometricUnlock)?
    private let logger = Logger(subsystem: "com.prizm", category: "UnlockViewModel")

    /// Tracks whether the last biometric attempt failed with invalidation,
    /// so the enrollment prompt can show the re-enroll copy.
    private var lastBiometricInvalidated = false

    // MARK: - Biometric context (LAAuthenticationView re-arming)

    /// The current `LAContext` shared with the embedded `LAAuthenticationView`.
    /// Replaced with a fresh instance on each re-arm so the view can re-authenticate.
    @Published private(set) var biometricContext = LAContext()

    /// Incremented on every re-arm so SwiftUI recreates `EmbeddedTouchIDView` via `.id()`.
    @Published private(set) var biometricContextVersion = 0

    // MARK: - Init

    init(
        auth: any AuthRepository,
        sync: any SyncUseCase,
        account: Account,
        embeddedBiometric: (any EmbeddedBiometricUnlock)? = nil
    ) {
        self.auth              = auth
        self.sync              = sync
        self.account           = account
        self.embeddedBiometric = embeddedBiometric
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
    /// On cancellation, re-arms the sensor immediately (always-armed behaviour —
    /// design Decision 2). On lockout or invalidation, shows an error and stops.
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
                // Intentionally NOT re-arming — invalidation requires password entry.
            } catch let err as AuthError where err == .biometricItemNotFound {
                // Keychain item deleted externally — degrade silently, no error shown.
                // biometricUnlockAvailable will return false now (flag cleared in repo).
                _ = err
                flowState = .unlock
            } catch let err as NSError
                where err.domain == NSOSStatusErrorDomain && err.code == Int(errSecUserCanceled) {
                // User cancelled — re-arm immediately so the sensor is always ready.
                // No error shown; password field stays available in parallel.
                flowState = .unlock
                triggerBiometricUnlockIfAvailable()
            } catch {
                // Lockout or other failure — show the error, stop re-arming.
                errorMessage = error.localizedDescription
                flowState = .unlock
            }
        }
    }

    /// Triggers biometric unlock via the embedded `LAAuthenticationView` path.
    /// Called from `.task(id: biometricContextVersion)` in `UnlockView` so the
    /// `LAAuthenticationView` is guaranteed to be in the window before
    /// `evaluatePolicy` is called — no system modal appears.
    func triggerEmbeddedBiometricIfAvailable() {
        guard biometricUnlockAvailable, let provider = embeddedBiometric else { return }
        Task {
            do {
                _ = try await provider.unlockWithBiometrics(context: biometricContext)
                lastBiometricInvalidated = false
                await checkEnrollmentOrSync()
            } catch let err as AuthError where err == .biometricInvalidated {
                lastBiometricInvalidated = true
                errorMessage = err.errorDescription
                flowState    = .unlock
            } catch let err as AuthError where err == .biometricItemNotFound {
                // Keychain item deleted externally — degrade silently, no error shown.
                _ = err
                flowState = .unlock
            } catch let laError as LAError {
                switch laError.code {
                case .biometryLockout:
                    // Locked out — show error, stop re-arming.
                    errorMessage = laError.localizedDescription
                    flowState    = .unlock
                default:
                    // Cancellation or transient failure — re-arm silently.
                    rearmBiometrics()
                }
            } catch {
                errorMessage = error.localizedDescription
                flowState    = .unlock
            }
        }
    }

    /// Triggers biometric unlock if available; no-op otherwise.
    /// Kept for use when `embeddedBiometric` is nil (test/legacy path).
    func triggerBiometricUnlockIfAvailable() {
        guard biometricUnlockAvailable else { return }
        unlockWithBiometrics()
    }

    /// Replaces `biometricContext` with a fresh `LAContext` and increments the version
    /// counter so `UnlockView` recreates `EmbeddedTouchIDView` via `.id()`.
    func rearmBiometrics() {
        biometricContext        = LAContext()
        biometricContextVersion += 1
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
            flowState = .loading
            await performSync()
        }
    }

    /// Called when the user dismisses the enrollment prompt without enabling.
    func dismissEnrollmentPrompt() {
        UserDefaults.standard.set(true, forKey: "biometricEnrollmentPromptShown")
        flowState = .loading
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

    /// After a successful unlock, checks whether to show the inline enrollment prompt
    /// before proceeding to sync (design Decision 3).
    ///
    /// Uses `auth.deviceBiometricCapable` (not `biometricUnlockAvailable`) so the check
    /// is mockable in tests and independent of the UserDefaults enabled flag.
    private func checkEnrollmentOrSync() async {
        let capable     = auth.deviceBiometricCapable
        let alreadyEnabled = UserDefaults.standard.bool(forKey: "biometricUnlockEnabled")
        let promptShown    = UserDefaults.standard.bool(forKey: "biometricEnrollmentPromptShown")

        if capable && !alreadyEnabled && !promptShown {
            let reason: EnrollmentReason = lastBiometricInvalidated ? .reEnrollAfterInvalidation : .firstTime
            flowState = .enrollmentPrompt(reason: reason)
            // performSync() is called by confirmEnrollBiometric() or dismissEnrollmentPrompt().
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
