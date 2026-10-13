import SwiftUI

/// Toggle for enabling/disabling biometric vault unlock in Settings.
///
/// Visible only when the device supports biometrics. Disabled with an explanatory
/// label when the vault is locked (enabling requires vault keys in memory), and
/// re-enables automatically once the vault is unlocked again — see
/// `BiometricUnlockToggleViewModel`.
struct BiometricUnlockToggle: View {

    // `BiometricUnlockToggleViewModel.init` is side-effect-free (see its own comment) —
    // safe to construct here even though SwiftUI can evaluate this `State(initialValue:)`
    // expression more than once per view identity (discarding all but the first result).
    // The one side effect that matters — subscribing to `.vaultDidUnlock` — is deferred to
    // `.onAppear` below via the idempotent `startObservingVaultUnlockIfNeeded()`, which is
    // guaranteed to run on the single kept instance, not on any discarded duplicate (#67
    // follow-up: constructing the observer directly in init caused a libmalloc heap-
    // corruption crash from repeated add/remove churn around lock/unlock).
    @State private var viewModel: BiometricUnlockToggleViewModel

    init(authRepository: any AuthRepository) {
        _viewModel = State(initialValue: BiometricUnlockToggleViewModel(authRepository: authRepository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("\(viewModel.biometryName) unlock", isOn: Binding(
                get: { viewModel.isEnabled },
                set: { viewModel.isEnabled = $0 }
            ))
            .disabled(viewModel.isToggleDisabled)
            .onChange(of: viewModel.isEnabled) { _, newValue in
                Task { await viewModel.toggleBiometric(enabled: newValue) }
            }

            if viewModel.showVaultLockedHint {
                Text("Unlock your vault to change this setting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            viewModel.startObservingVaultUnlockIfNeeded()
        }
    }
}
