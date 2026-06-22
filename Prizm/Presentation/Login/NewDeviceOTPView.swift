import SwiftUI

// MARK: - NewDeviceOTPView

/// Verification screen shown when the Bitwarden Cloud server does not recognise the device
/// (HTTP 400, `"error": "device_error"`). The user must enter the one-time code sent to
/// their registered email address to complete the login.
struct NewDeviceOTPView: View {

    @ObservedObject var viewModel: LoginViewModel

    @FocusState private var otpFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // MARK: Header
            VStack(spacing: 4) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(Typography.screenIcon)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Check your email")
                    .font(Typography.screenHeading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(AccessibilityID.Login.newDeviceOtpHeader)
                Text("Check your email for a verification code.")
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // MARK: OTP field
            VStack(alignment: .leading, spacing: 4) {
                Text("Verification code")
                    .font(Typography.fieldLabelProminent)
                    .foregroundStyle(.secondary)
                TextField("000000", text: $viewModel.otpCode)
                    .textFieldStyle(.roundedBorder)
                    .focused($otpFieldFocused)
                    .frame(width: 200)
                    .accessibilityIdentifier(AccessibilityID.Login.newDeviceOtpField)
                    .accessibilityLabel("Verification code")
                    .onSubmit { submitIfReady() }
            }

            // MARK: Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.screenBody)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .transition(.opacity)
                    .accessibilityIdentifier(AccessibilityID.Login.otpErrorMessage)
            }

            // MARK: Sign In button
            Button(action: submitIfReady) {
                if case .loading = viewModel.flowState {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 200)
                } else {
                    Text("Sign In")
                        .frame(width: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSignInDisabled)
            .keyboardShortcut(.return, modifiers: [])

            // MARK: Resend button
            Button("Resend code") {
                viewModel.resendOTP()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier(AccessibilityID.Login.resendOtpButton)
            .accessibilityLabel("Resend code")

            // MARK: Cancel button
            Button("Cancel") {
                viewModel.cancelOTP()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier(AccessibilityID.Login.cancelOtpButton)
            .accessibilityLabel("Cancel")

            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, 32)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear {
            otpFieldFocused = true
            AccessibilityNotification.Announcement("Check your email for a verification code").post()
        }
    }

    // MARK: - Private

    private func submitIfReady() {
        guard !viewModel.isSignInDisabled else { return }
        viewModel.submitOTP()
    }
}
