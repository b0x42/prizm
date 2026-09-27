import SwiftUI

// MARK: - LoginView

/// The initial authentication screen (User Story 1, FR-001–FR-010).
///
/// Collects server URL, email, and master password, then initiates the login flow
/// via `LoginViewModel`. The view itself is stateless - all logic lives in the VM.
struct LoginView: View {

    @ObservedObject var viewModel: LoginViewModel

    /// Focus state used to advance through fields on Return.
    @FocusState private var focusedField: Field?
    @State private var isPasswordVisible = false

    private enum Field: Hashable {
        case serverURL, email, password
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                // MARK: Header
                VStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(Typography.screenIcon)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Prizm")
                        .font(Typography.screenHeading)
                    Text("Self-hosted vault")
                        .font(Typography.fieldLabel)
                        .foregroundStyle(.secondary)
                }

                // MARK: Form fields
                VStack(spacing: 12) {
                    // Server URL - FR-001
                    LabeledContent("Server URL") {
                        TextField("https://vault.example.com", text: $viewModel.serverURL)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .serverURL)
                            .autocorrectionDisabled()
                            .onSubmit { focusedField = .email }
                            .accessibilityIdentifier(AccessibilityID.Login.serverURLField)
                            .authenticationInputStyle(isFocused: focusedField == .serverURL)
                    }

                    // Email - FR-003
                    LabeledContent("Email") {
                        TextField("you@example.com", text: $viewModel.email)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .email)
                            .autocorrectionDisabled()
                            .onSubmit { focusedField = .password }
                            .accessibilityIdentifier(AccessibilityID.Login.emailField)
                            .authenticationInputStyle(isFocused: focusedField == .email)
                    }

                    // Master password - FR-005
                    LabeledContent("Master password") {
                        passwordField
                    }
                }
                .labeledContentStyle(.vertical)
                .frame(width: LayoutMetrics.authenticationFormWidth)

                // MARK: Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.screenBody)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: LayoutMetrics.authenticationFormWidth)
                        .transition(.opacity)
                        .accessibilityIdentifier(AccessibilityID.Login.errorMessage)
                }

                // MARK: Sign In button - FR-007
                Button(action: signIn) {
                    if case .loading = viewModel.flowState {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(
                    width: LayoutMetrics.authenticationFormWidth,
                    height: LayoutMetrics.authenticationInputHeight
                )
                .disabled(isSignInDisabled)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityIdentifier(AccessibilityID.Login.signInButton)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { focusedField = .serverURL }
    }

    // MARK: - Private helpers

    private var passwordField: some View {
        HStack(spacing: Spacing.fieldActionGap) {
            Group {
                if isPasswordVisible {
                    TextField("Enter master password", text: $viewModel.password)
                } else {
                    SecureField("Enter master password", text: $viewModel.password)
                }
            }
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .password)
            .onSubmit { signIn() }
            .accessibilityIdentifier(AccessibilityID.Login.passwordField)

            Button {
                isPasswordVisible.toggle()
                focusedField = .password
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(isPasswordVisible ? "Hide password" : "Show password")
            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            .accessibilityValue(isPasswordVisible ? "Password visible" : "Password hidden")
        }
        .authenticationInputStyle(isFocused: focusedField == .password)
    }

    private var isSignInDisabled: Bool {
        if case .loading = viewModel.flowState { return true }
        return viewModel.serverURL.isEmpty || viewModel.email.isEmpty || viewModel.password.isEmpty
    }

    private func signIn() {
        guard !isSignInDisabled else { return }
        viewModel.signIn()
    }
}

private extension View {
    func authenticationInputStyle(isFocused: Bool) -> some View {
        font(Typography.fieldValue)
            .padding(.horizontal, Spacing.rowHorizontal)
            .frame(height: LayoutMetrics.authenticationInputHeight)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: Spacing.itemIconCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.itemIconCornerRadius)
                    .stroke(
                        isFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: isFocused ? 2 : 1
                    )
            }
    }
}


