import SwiftUI

// MARK: - AttachmentRowView

/// A single row in the Attachments section card displaying an attachment's name and size.
///
/// When `attachment.isUploadIncomplete` is true the row shows an "Upload incomplete" warning
/// and a Retry button instead of the normal Open / Save to Disk actions. Normal action buttons
/// (Open, Save to Disk, Delete) are added by `AttachmentRowViewModel` in task 7.
struct AttachmentRowView: View {

    let attachment: Attachment

    // Action callbacks — wired by the parent view.
    // Default no-ops keep task-5 callers (no ViewModel yet) compiling.
    var onOpen:       () -> Void = {}
    var onSaveToDisk: () -> Void = {}
    var onDelete:     () -> Void = {}
    var onRetry:      () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // File icon + name + size
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.fileName)
                        .font(Typography.fieldValue)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(attachment.sizeName)
                        .font(Typography.listSubtitle)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if attachment.isUploadIncomplete {
                incompleteActions
            } else if isHovered {
                normalActions
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityIdentifier(AccessibilityID.Attachment.row(attachment.id))
    }

    // MARK: - Normal actions (hover-activated)

    @ViewBuilder
    private var normalActions: some View {
        HStack(spacing: 8) {
            Button { onOpen() } label: {
                Text("open")
                    .font(.headline)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open")
            .accessibilityIdentifier(AccessibilityID.Attachment.openButton(attachment.id))

            Button { onSaveToDisk() } label: {
                Text("save")
                    .font(.headline)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save to Disk")
            .accessibilityHint("Saves file to your chosen location")
            .accessibilityIdentifier(AccessibilityID.Attachment.saveButton(attachment.id))

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .imageScale(.medium)
                    .foregroundStyle(Color.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
            .accessibilityIdentifier(AccessibilityID.Attachment.deleteButton(attachment.id))
        }
        .transition(.opacity)
    }

    // MARK: - Upload-incomplete indicator (task 6d.1)

    @ViewBuilder
    private var incompleteActions: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .imageScale(.small)
            Text("Upload incomplete")
                .font(Typography.utility)
                .foregroundStyle(.orange)
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderless)
            .font(Typography.utility)
            .foregroundStyle(Color.accentColor)
            .accessibilityIdentifier(AccessibilityID.Attachment.retryButton(attachment.id))
        }
    }
}
