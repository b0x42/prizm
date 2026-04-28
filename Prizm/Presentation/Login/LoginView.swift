import SwiftUI

// MARK: - LoginView

/// The initial authentication screen (User Story 1, FR-001–FR-010).
///
/// Collects server type, email, and master password, then initiates the login flow
/// via `LoginViewModel`. The view itself is stateless — all logic lives in the VM.
struct LoginView: View {

    @ObservedObject var viewModel: LoginViewModel

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case serverURL, email, password
    }

    var body: some View {
        VStack(spacing: 24) {
            // MARK: Header
            VStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(Typography.screenIcon)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Prizm")
                    .font(Typography.screenHeading)
                    .accessibilityIdentifier(AccessibilityID.Login.headerTitle)
                // Server-type picker — replaces the static subtitle
                Picker("Server", selection: $viewModel.serverType) {
                    ForEach([ServerType.cloudUS, .cloudEU, .selfHosted], id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .accessibilityIdentifier(AccessibilityID.Login.serverTypePicker)
                .accessibilityLabel("Server")
                .accessibilityValue(pickerLabel(for: viewModel.serverType))
            }
            .padding(.top, 24)

            // MARK: Form fields
            VStack(spacing: 12) {
                // Server URL — only shown for self-hosted
                if viewModel.serverType == .selfHosted {
                    LabeledContent("Server URL") {
                        TextField("https://vault.example.com", text: $viewModel.serverURL)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .serverURL)
                            .autocorrectionDisabled()
                            .onSubmit { focusedField = .email }
                            .accessibilityIdentifier(AccessibilityID.Login.serverURLField)
                    }
                }

                // Email
                LabeledContent("Email") {
                    TextField("you@example.com", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .email)
                        .autocorrectionDisabled()
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier(AccessibilityID.Login.emailField)
                }

                // Master password
                LabeledContent("Master password") {
                    SecureField("Enter master password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .onSubmit { signIn() }
                        .accessibilityIdentifier(AccessibilityID.Login.passwordField)
                }
            }
            .labeledContentStyle(.vertical)
            .frame(maxWidth: 360)

            // MARK: Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.screenBody)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .transition(.opacity)
                    .accessibilityIdentifier(AccessibilityID.Login.errorMessage)
            }

            // MARK: Sign In button
            Button(action: signIn) {
                if case .loading = viewModel.flowState {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 360)
            .disabled(viewModel.isSignInDisabled)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier(AccessibilityID.Login.signInButton)

            Spacer()
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, 32)
        .frame(minWidth: 480, minHeight: 400)
        .onAppear {
            focusedField = viewModel.serverType == .selfHosted ? .serverURL : .email
        }
    }

    // MARK: - Private helpers

    private func signIn() {
        guard !viewModel.isSignInDisabled else { return }
        viewModel.signIn()
    }

    private func pickerLabel(for type: ServerType) -> String { type.displayName }
}
