import SwiftUI

// MARK: - UnlockView

/// The vault unlock screen shown to returning users (User Story 2, FR-003, FR-039).
///
/// Displays the stored email read-only and collects the master password locally.
/// No network call is made — the vault key is re-derived from the password.
struct UnlockView: View {

    @ObservedObject var viewModel: UnlockViewModel

    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // MARK: Header
            VStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Vault locked")
                    .font(.title.bold())
                    .accessibilityIdentifier(AccessibilityID.Unlock.headerTitle)
                Text("Enter your master password to unlock.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            // MARK: Form
            VStack(spacing: 12) {
                // Email — read-only (FR-003)
                LabeledContent("Email") {
                    Text(viewModel.email)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityIdentifier(AccessibilityID.Unlock.emailLabel)
                }

                // Master password
                LabeledContent("Master password") {
                    SecureField("Enter master password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .focused($passwordFocused)
                        .onSubmit { unlockIfReady() }
                        .accessibilityIdentifier(AccessibilityID.Unlock.passwordField)
                }
            }
            .labeledContentStyle(.vertical)
            .frame(maxWidth: 360)

            // MARK: Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .transition(.opacity)
                    .accessibilityIdentifier(AccessibilityID.Unlock.errorMessage)
            }

            // MARK: Unlock button
            Button(action: unlockIfReady) {
                if case .loading = viewModel.flowState {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Unlock")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 360)
            .disabled(isUnlockDisabled)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier(AccessibilityID.Unlock.unlockButton)

            // MARK: Sign in with a different account — FR-039
            Button("Sign in with a different account") {
                viewModel.signInWithDifferentAccount()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(AccessibilityID.Unlock.switchAccount)

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 32)
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { passwordFocused = true }
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
}

// MARK: - Vertical LabeledContentStyle (shared with LoginView)

private struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            configuration.content
        }
    }
}

private extension LabeledContentStyle where Self == VerticalLabeledContentStyle {
    static var vertical: VerticalLabeledContentStyle { .init() }
}
