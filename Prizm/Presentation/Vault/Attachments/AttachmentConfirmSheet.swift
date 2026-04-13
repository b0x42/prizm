import SwiftUI

// MARK: - AttachmentConfirmSheet

/// Sheet shown after the user selects a file to attach (task 6.3).
///
/// Displays the file name, formatted size, any advisory or error messages,
/// a progress indicator during upload, and Confirm / Cancel buttons.
///
/// Wired to `AttachmentAddViewModel` — all state flows from the ViewModel.
/// The sheet dismisses itself when `viewModel.isDismissed` becomes true.
struct AttachmentConfirmSheet: View {

    let viewModel: AttachmentAddViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Text("Add Attachment")
                .font(Typography.pageTitle)
                .padding(.top, Spacing.pageTop)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, Spacing.pageHeaderBottom)

            Divider()

            // File details
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("File name", value: viewModel.fileName)
                    .font(Typography.fieldValue)

                LabeledContent("Size") {
                    Text(ByteCountFormatter.string(
                        fromByteCount: Int64(viewModel.fileSizeBytes),
                        countStyle: .file
                    ))
                    .font(Typography.fieldValue)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.vertical, Spacing.rowVertical * 2)

            // Advisory (large file warning)
            if let advisory = viewModel.sizeAdvisory {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(advisory)
                        .font(Typography.fieldLabel)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, Spacing.rowVertical)
            }

            // Upload error
            if let error = viewModel.uploadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text(error)
                        .font(Typography.fieldValue)
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.vertical, Spacing.rowVertical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(Opacity.errorBanner(contrast)))
            }

            // Progress indicator during upload
            if viewModel.isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading…")
                        .font(Typography.fieldValue)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, Spacing.rowVertical)
            }

            Divider()

            // Confirm / Cancel buttons
            HStack {
                // Cancel remains enabled during upload (task 6.4b)
                Button("Cancel") {
                    viewModel.cancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Confirm") {
                    viewModel.confirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isUploading)
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.vertical, Spacing.rowVertical * 1.5)
        }
        .frame(minWidth: 400, idealWidth: 440)
        .onChange(of: viewModel.isDismissed) { _, dismissed in
            if dismissed { dismiss() }
        }
    }
}
