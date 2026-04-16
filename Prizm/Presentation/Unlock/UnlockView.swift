import AppKit
import LocalAuthentication
import SwiftUI

// MARK: - UnlockView

/// The vault unlock screen shown to returning users (User Story 2, FR-003, FR-039).
///
/// Modelled after the macOS Passwords lock screen: app icon with biometric badge,
/// title "Prizm Is Locked", email inline in the subtitle, and a single centered
/// password field. Biometric unlock auto-triggers on appearance; the user can also
/// type their password and press Return.
struct UnlockView: View {

    @ObservedObject var viewModel: UnlockViewModel

    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: App icon + biometric badge
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)

                // Inline Touch ID badge — LAAuthenticationView routes auth through
                // the app's own view hierarchy so no system modal dialog appears.
                // Re-armed via .id(biometricContextVersion) after each attempt.
                if viewModel.biometricUnlockAvailable {
                    EmbeddedTouchIDView(context: viewModel.biometricContext)
                    .frame(width: 32, height: 32)
                    .offset(x: 6, y: 6)
                    .id(viewModel.biometricContextVersion)
                    .accessibilityIdentifier(AccessibilityID.Unlock.biometricBadge)
                }
            }
            .padding(.bottom, 16)

            // MARK: Title
            Text("Prizm Is Locked")
                .font(Typography.screenHeading)
                .accessibilityIdentifier(AccessibilityID.Unlock.headerTitle)
                .padding(.bottom, 6)

            // MARK: Subtitle — includes email so no separate field is needed (FR-003)
            Text(subtitleText)
                .font(Typography.screenBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.bottom, 20)

            // MARK: Password field / loading
            switch viewModel.flowState {
            case .loading:
                ProgressView()
                    .controlSize(.regular)
                    .frame(width: 200)
                    .accessibilityIdentifier(AccessibilityID.Unlock.unlockButton)
            case .syncing(let message):
                VStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(message)
                        .font(Typography.screenBody)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 200)
            default:
                SecureField("Enter password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .focused($passwordFocused)
                    .onSubmit { unlockIfReady() }
                    .accessibilityIdentifier(AccessibilityID.Unlock.passwordField)
            }

            // MARK: Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.screenBody)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .transition(.opacity)
                    .padding(.top, 10)
                    .accessibilityIdentifier(AccessibilityID.Unlock.errorMessage)
            }

            Spacer()

            // MARK: Sign in with a different account — FR-039
            Button("Sign in with a different account") {
                viewModel.signInWithDifferentAccount()
            }
            .buttonStyle(.plain)
            .font(Typography.screenBody)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
            .accessibilityIdentifier(AccessibilityID.Unlock.switchAccount)
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { passwordFocused = true }
        // .task(id:) re-fires whenever biometricContextVersion changes (re-arm).
        // By the time the task runs, SwiftUI has re-rendered EmbeddedTouchIDView
        // with the new LAContext — so evaluatePolicy routes inline, not to a modal.
        .task(id: viewModel.biometricContextVersion) {
            viewModel.triggerEmbeddedBiometricIfAvailable()
        }
        .sheet(isPresented: $viewModel.showEnrollmentPrompt) {
            BiometricEnrollmentPromptView(
                reason: viewModel.enrollmentReason,
                onEnable: { viewModel.confirmEnrollBiometric() },
                onDismiss: { viewModel.dismissEnrollmentPrompt() }
            )
            .accessibilityIdentifier(AccessibilityID.Unlock.enrollmentPrompt)
        }
    }

    // MARK: - Private

    private var isUnlockDisabled: Bool {
        if case .loading = viewModel.flowState { return true }
        return viewModel.password.isEmpty
    }

    private func unlockIfReady() {
        guard !isUnlockDisabled else { return }
        viewModel.unlock()
    }

    /// Subtitle varies by whether biometric unlock is available.
    private var subtitleText: String {
        if viewModel.biometricUnlockAvailable {
            return "\(biometricMethodName) or enter the password for \(viewModel.email) to unlock."
        } else {
            return "Enter the password for \(viewModel.email) to unlock."
        }
    }

    private var biometricMethodName: String {
        switch LAContext().biometryType {
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        default:       return "Biometrics"
        }
    }

}

