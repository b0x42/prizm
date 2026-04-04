import SwiftUI

// MARK: - AttachmentBatchSheet

/// Sheet shown when files are dropped onto the Attachments section card (task 6b.3).
///
/// Lists all dropped files with name, size, and per-row state indicators:
/// - Too-large: warning badge ("Exceeds 500 MB limit")
/// - Uploading: progress spinner
/// - Succeeded: checkmark
/// - Failed: inline error message
///
/// Confirm/Cancel buttons are driven by `viewModel.canConfirm`.
/// Cancel remains enabled during upload and cancels all in-flight tasks (task 6b.7).
struct AttachmentBatchSheet: View {

    let viewModel: AttachmentBatchViewModel

    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Text("Add Attachments")
                .font(Typography.pageTitle)
                .padding(.top, Spacing.pageTop)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, Spacing.pageHeaderBottom)

            Divider()

            // File list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.items) { item in
                        if item.id != viewModel.items.first?.id { Divider() }
                        batchItemRow(item)
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 400)

            Divider()

            // Confirm / Cancel
            HStack {
                Button("Cancel") {
                    viewModel.cancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Upload") {
                    viewModel.confirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canConfirm)
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.vertical, Spacing.rowVertical * 1.5)
        }
        .frame(minWidth: 440, idealWidth: 480)
        .onChange(of: viewModel.isDismissed) { _, dismissed in
            if dismissed { isPresented = false }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func batchItemRow(_ item: AttachmentBatchItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(Typography.fieldValue)
                    .lineLimit(1)
                Text(item.sizeName)
                    .font(Typography.listSubtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            stateView(for: item)
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }

    @ViewBuilder
    private func stateView(for item: AttachmentBatchItem) -> some View {
        switch item.state {
        case .valid:
            EmptyView()

        case .tooLarge:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .imageScale(.small)
                Text("Exceeds 500 MB limit")
                    .font(Typography.utility)
                    .foregroundStyle(.orange)
            }

        case .uploading:
            ProgressView()
                .controlSize(.small)

        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
                    .imageScale(.small)
                Text(message)
                    .font(Typography.utility)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }
}
