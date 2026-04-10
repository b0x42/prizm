import LocalAuthentication
import SwiftUI

/// Toggle for enabling/disabling biometric vault unlock in Settings.
///
/// Visible only when the device supports biometrics. Disabled with an explanatory
/// label when the vault is locked (enabling requires vault keys in memory).
struct BiometricUnlockToggle: View {

    let authRepository: any AuthRepository

    @State private var isEnabled: Bool = UserDefaults.standard.bool(forKey: "biometricUnlockEnabled")
    @State private var isProcessing = false

    private var biometryName: String {
        switch LAContext().biometryType {
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        default:       return "Biometric"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("\(biometryName) unlock", isOn: $isEnabled)
                .disabled(isProcessing)
                .onChange(of: isEnabled) { _, newValue in
                    Task { await toggleBiometric(enabled: newValue) }
                }

            if !authRepository.biometricUnlockAvailable && !isEnabled {
                Text("Unlock your vault to change this setting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleBiometric(enabled: Bool) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            if enabled {
                try await authRepository.enableBiometricUnlock()
            } else {
                try await authRepository.disableBiometricUnlock()
            }
        } catch {
            // Revert the toggle on failure.
            isEnabled = !enabled
        }
    }
}
