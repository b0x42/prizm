import SwiftUI
import UniformTypeIdentifiers

/// Password exists only while previewing. Confirmation explicitly binds the shown origin.
struct ClientCertificateImportView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var password = ""
    @State private var choosingFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.cardBottom) {
            Text("Import client certificate").font(Typography.sectionHeader).accessibilityAddTraits(.isHeader)
            Text(viewModel.certificateOrigin ?? viewModel.serverURL).font(Typography.fieldValue).textSelection(.enabled)
            if let certificate = viewModel.certificatePreview {
                certificateDetails(certificate)
                HStack {
                    Button("Cancel") { viewModel.cancelCertificatePreview(); dismiss() }
                    Button("Use for this server") {
                        Task { if await viewModel.confirmCertificate() { dismiss() } }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Confirm client certificate for this server")
                    .disabled(viewModel.certificateBusy)
                }
            } else {
                Button(file?.lastPathComponent ?? "Choose .p12 / .pfx…") { choosingFile = true }
                    .accessibilityLabel("Choose PKCS12 certificate file")
                SecureField("Import password", text: $password)
                    .accessibilityLabel("PKCS12 import password")
                HStack {
                    Button("Cancel") { password = ""; dismiss() }
                    Button("Inspect certificate") {
                        guard let file else { return }
                        viewModel.previewCertificate(file: file, password: password)
                        password = ""
                    }
                    .disabled(file == nil)
                    .accessibilityLabel("Validate and preview certificate")
                }
            }
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(Typography.screenBody)
                    .foregroundStyle(.red)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.pageMargin)
        .frame(width: 480)
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data, UTType(filenameExtension: "pfx") ?? .data]) { result in
            switch result {
            case .success(let url): file = url
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .onDisappear { password = ""; viewModel.cancelCertificatePreview() }
    }

    private func certificateDetails(_ certificate: ClientCertificateDetails) -> some View {
        VStack(alignment: .leading, spacing: Spacing.headerGap) {
            Text(certificate.name).font(Typography.fieldValue)
            Text("Issuer: \(certificate.issuer)").font(Typography.utility)
            Text("Valid: \(certificate.notBefore.formatted(date: .abbreviated, time: .omitted)) – \(certificate.notAfter.formatted(date: .abbreviated, time: .omitted))")
                .font(Typography.utility)
            Text("SHA-256: \(certificate.fingerprint)").font(Typography.utility).textSelection(.enabled)
            Text("Attachments are unavailable for mTLS servers in this prototype.").font(Typography.utility)
        }
    }
}
