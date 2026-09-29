import SwiftUI

/// Toggle for enabling/disabling biometric vault unlock in Settings.
///
/// Visible only when the device supports biometrics. Disabled with an explanatory
/// label when the vault is locked (enabling requires vault keys in memory), and
/// re-enables automatically once the vault is unlocked again — see
/// `BiometricUnlockToggleViewModel`.
struct BiometricUnlockToggle: View {

    @State private var viewModel: BiometricUnlockToggleViewModel

    init(authRepository: any AuthRepository) {
        _viewModel = State(initialValue: BiometricUnlockToggleViewModel(authRepository: authRepository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("\(viewModel.biometryName) unlock", isOn: $viewModel.isEnabled)
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
    }
}
