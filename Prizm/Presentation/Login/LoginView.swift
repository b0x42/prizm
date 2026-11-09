import SwiftUI

// MARK: - LoginView

/// The initial authentication screen (User Story 1, FR-001–FR-010).
///
/// Collects server URL, email, and master password, then initiates the login flow
/// via `LoginViewModel`. The view itself is stateless — all logic lives in the VM.
struct LoginView: View {

    @State private var showsCertificateImport = false
    @ObservedObject var viewModel: LoginViewModel

    /// Focus state used to advance through fields on Return.
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case serverURL, email, password
    }

    var body: some View {
        // Keep errors and actions reachable when the certificate section or a long
        // connection error makes the form taller than the available window.
        ScrollView {
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
                .padding(.top, 24)

                // MARK: Form fields
                VStack(spacing: 12) {
                    // Server URL — FR-001
                    LabeledContent("Server URL") {
                        TextField("https://vault.example.com", text: $viewModel.serverURL)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .serverURL)
                            .autocorrectionDisabled()
                            .onSubmit { focusedField = .email }
                            .accessibilityIdentifier(AccessibilityID.Login.serverURLField)
                    }

                    // Email — FR-003
                    LabeledContent("Email") {
                        TextField("you@example.com", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .email)
                            .autocorrectionDisabled()
                            .onSubmit { focusedField = .password }
                            .accessibilityIdentifier(AccessibilityID.Login.emailField)
                    }

                    // Master password — FR-005
                    LabeledContent("Master password") {
                        SecureField("Enter master password", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .password)
                            .onSubmit { signIn() }
                            .accessibilityIdentifier(AccessibilityID.Login.passwordField)
                    }
                }
                .disabled(viewModel.flowState != .login || viewModel.certificateBusy)
                .labeledContentStyle(.vertical)
                .frame(maxWidth: 360)

                if viewModel.supportsClientCertificates {
                    VStack(alignment: .leading, spacing: Spacing.headerGap) {
                        Text("Client certificate (optional)")
                            .font(Typography.fieldLabelProminent)
                            .accessibilityAddTraits(.isHeader)
                        if let certificate = viewModel.configuredCertificate {
                            Text(certificate.name).font(Typography.fieldValue)
                            Text("Assigned to this HTTPS server").font(Typography.utility)
                        }
                        HStack {
                            Button(viewModel.configuredCertificate == nil ? "Import .p12 / .pfx…" : "Replace certificate…") {
                                showsCertificateImport = true
                            }
                            .accessibilityLabel("Import TLS client certificate")
                            .disabled(viewModel.serverURL.isEmpty || viewModel.certificateBusy || viewModel.flowState != .login)
                            if viewModel.configuredCertificate != nil {
                                Button("Remove") { Task { await viewModel.removeCertificate() } }
                                    .accessibilityLabel("Remove client certificate for this server")
                                    .disabled(viewModel.certificateBusy || viewModel.flowState != .login)
                            }
                        }
                    }
                    .frame(maxWidth: 360, alignment: .leading)
                }

                // MARK: Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Typography.screenBody)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 360)
                        .transition(.opacity)
                        .accessibilityIdentifier(AccessibilityID.Login.errorMessage)
                }

                // MARK: Sign In button — FR-007
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
                .disabled(isSignInDisabled)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityIdentifier(AccessibilityID.Login.signInButton)

            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, 32)
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { focusedField = .serverURL; viewModel.refreshCertificate() }
        .sheet(isPresented: $showsCertificateImport, onDismiss: { viewModel.cancelCertificatePreview() }) {
            ClientCertificateImportView(viewModel: viewModel)
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
    }

    // MARK: - Private helpers

    private var isSignInDisabled: Bool {
        if viewModel.certificateBusy { return true }
        if case .loading = viewModel.flowState { return true }
        return viewModel.serverURL.isEmpty || viewModel.email.isEmpty || viewModel.password.isEmpty
    }

    private func signIn() {
        guard !isSignInDisabled else { return }
        viewModel.signIn()
    }
}
