import LocalAuthentication
import Observation

// MARK: - BiometricUnlockToggleViewModel

/// State and toggle logic for the "Touch ID unlock" control in Settings → Security.
///
/// Extracted out of `BiometricUnlockToggle`'s `@State` so the vault-locked recovery
/// behavior is unit-testable without XCUITest app-launch infrastructure (see design.md
/// for change `fix-touch-id-toggle-disabled`).
@Observable
@MainActor
final class BiometricUnlockToggleViewModel {

    private let authRepository: any AuthRepository
    private nonisolated(unsafe) var unlockObserver: NSObjectProtocol?

    var isEnabled: Bool
    var isProcessing = false

    /// `true` when a previous toggle attempt failed because the vault was locked.
    /// Cleared automatically when the vault is subsequently unlocked (`.vaultDidUnlock`),
    /// not just on a successful retry — see settings-screen spec "Biometric toggle
    /// re-enables after the vault is unlocked" (#67).
    var showVaultLockedHint = false

    var isToggleDisabled: Bool { isProcessing || showVaultLockedHint }

    var biometryName: String {
        switch LAContext().biometryType {
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        default:       return "Biometric"
        }
    }

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
        self.isEnabled = UserDefaults.standard.bool(forKey: "biometricUnlockEnabled")
        // Deliberately no side effects here beyond this. `BiometricUnlockToggle` constructs
        // this type inside a `State(initialValue:)` expression, which SwiftUI can evaluate
        // more than once per view identity (discarding all but the first result) — a
        // side-effecting NotificationCenter registration here previously caused observer
        // churn and a libmalloc heap-corruption crash around lock/unlock (#67 follow-up).
        // The real subscription happens in `startObservingVaultUnlockIfNeeded()`, called
        // from `.onAppear` on the rendered toggle — guaranteed to run once per identity.
    }

    deinit {
        if let obs = unlockObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    /// Idempotent — safe to call from `.onAppear`, which can fire more than once for the
    /// same view identity (e.g. window hide/show).
    func startObservingVaultUnlockIfNeeded() {
        guard unlockObserver == nil else { return }
        subscribeToVaultUnlock()
    }

    private func subscribeToVaultUnlock() {
        unlockObserver = NotificationCenter.default.addObserver(
            forName: .vaultDidUnlock,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showVaultLockedHint = false
            }
        }
    }

    func toggleBiometric(enabled: Bool) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            if enabled {
                try await authRepository.enableBiometricUnlock()
            } else {
                try await authRepository.disableBiometricUnlock()
            }
            showVaultLockedHint = false
        } catch {
            isEnabled = !enabled
            if (error as? AuthError) == .biometricUnavailable {
                showVaultLockedHint = true
            }
        }
    }
}
