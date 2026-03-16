import SwiftUI

// MARK: - TOTPPromptView

/// Two-factor authentication prompt shown when the server requires an authenticator-app code.
/// (User Story 1, FR-016, FR-050)
///
/// Uses the same `LoginViewModel` as `LoginView`; the VM transitions to `.vault` on success.
struct TOTPPromptView: View {

    @ObservedObject var viewModel: LoginViewModel

    @State private var totpCode:      String = ""
    @State private var rememberDevice: Bool  = false
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // MARK: Header
            VStack(spacing: 4) {
                Image(systemName: "key.2.on.ring.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)
                Text("Two-step login")
                    .font(.title.bold())
                Text("Enter the 6-digit code from your authenticator app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // MARK: Code field
            VStack(alignment: .leading, spacing: 4) {
                Text("Authentication code")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("000000", text: $totpCode)
                    .textFieldStyle(.roundedBorder)
                    .focused($codeFieldFocused)
                    .frame(width: 200)
                    .onChange(of: totpCode) { _, new in
                        // Enforce 6 digits.
                        totpCode = String(new.filter(\.isNumber).prefix(6))
                    }
                    .onSubmit { submitIfReady() }
            }

            // MARK: Remember device — FR-050
            Toggle("Remember this device", isOn: $rememberDevice)
                .frame(width: 200, alignment: .leading)

            // MARK: Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            // MARK: Submit button
            Button(action: submitIfReady) {
                if case .loading = viewModel.flowState {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 200)
                } else {
                    Text("Continue")
                        .frame(width: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitDisabled)
            .keyboardShortcut(.return, modifiers: [])

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 32)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { codeFieldFocused = true }
    }

    // MARK: - Private helpers

    private var isSubmitDisabled: Bool {
        if case .loading = viewModel.flowState { return true }
        return totpCode.count != 6
    }

    private func submitIfReady() {
        guard !isSubmitDisabled else { return }
        viewModel.submitTOTP(code: totpCode, rememberDevice: rememberDevice)
    }
}
