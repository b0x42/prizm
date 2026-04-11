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

                // Badge indicates which biometric method is available.
                // Offset slightly outside the icon corner to match the
                // Passwords app visual treatment.
                if viewModel.biometricUnlockAvailable {
                    Image(systemName: biometricSystemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.red, in: Circle())
                        .offset(x: 6, y: 6)
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

            // MARK: Password field / loading / enrollment
            // The .enrollmentPrompt flow state replaces the entire lower section inline
            // (design Decision 3 — no sheet, no modal).
            switch viewModel.flowState {
            case .enrollmentPrompt(let reason):
                enrollmentSection(reason: reason)
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
            if case .enrollmentPrompt = viewModel.flowState {
                // Hide account-switching during enrollment to keep the offer focused.
                EmptyView()
            } else {
                Button("Sign in with a different account") {
                    viewModel.signInWithDifferentAccount()
                }
                .buttonStyle(.plain)
                .font(Typography.screenBody)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
                .accessibilityIdentifier(AccessibilityID.Unlock.switchAccount)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { passwordFocused = true }
        .task { viewModel.triggerBiometricUnlockIfAvailable() }
    }

    // MARK: - Inline enrollment section (design Decision 3)

    @ViewBuilder
    private func enrollmentSection(reason: EnrollmentReason) -> some View {
        VStack(spacing: 16) {
            Text(enrollmentHeading(reason: reason))
                .font(Typography.screenHeading)
                .multilineTextAlignment(.center)

            Text(enrollmentBody(reason: reason))
                .font(Typography.screenBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            VStack(spacing: 8) {
                Button(enrollmentEnableLabel(reason: reason)) {
                    viewModel.confirmEnrollBiometric()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])

                Button("Not now") {
                    viewModel.dismissEnrollmentPrompt()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Unlock.enrollmentPrompt)
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
            return "\(biometricMethodName) or enter the password for the user \"\(viewModel.email)\" to unlock."
        } else {
            return "Enter the password for the user \"\(viewModel.email)\" to unlock."
        }
    }

    private var biometricMethodName: String {
        switch LAContext().biometryType {
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        default:       return "Biometrics"
        }
    }

    private var biometricSystemImage: String {
        switch LAContext().biometryType {
        case .touchID: return "touchid"
        case .faceID:  return "faceid"
        default:       return "person.badge.key"
        }
    }

    private func enrollmentHeading(reason: EnrollmentReason) -> String {
        switch reason {
        case .firstTime:                 return "Enable \(biometricMethodName) to unlock faster"
        case .reEnrollAfterInvalidation: return "Re-enable \(biometricMethodName)"
        }
    }

    private func enrollmentBody(reason: EnrollmentReason) -> String {
        switch reason {
        case .firstTime:
            return "You can also enable this in Settings at any time."
        case .reEnrollAfterInvalidation:
            return "Your \(biometricMethodName) settings changed — a fingerprint was added or removed. For your security, Prizm disabled \(biometricMethodName) unlock. Would you like to re-enable it?"
        }
    }

    private func enrollmentEnableLabel(reason: EnrollmentReason) -> String {
        switch reason {
        case .firstTime:                 return "Enable \(biometricMethodName)"
        case .reEnrollAfterInvalidation: return "Re-enable \(biometricMethodName)"
        }
    }
}

