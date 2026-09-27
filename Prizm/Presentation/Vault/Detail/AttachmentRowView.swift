import SwiftUI

// MARK: - AttachmentRowView

/// A single row in the Attachments section card displaying an attachment's name and size.
///
/// Read mode offers Quick Look preview and download. Edit mode exposes mutation controls.
struct AttachmentRowView: View {

    let attachment: Attachment
    var isEditing = false

    // Action callbacks - wired by the parent view.
    // Default no-ops keep task-5 callers (no ViewModel yet) compiling.
    var onPreview:    () -> Void = {}
    var onSaveToDisk: () -> Void = {}
    var onDelete:     () -> Void = {}
    var onRetry:      () -> Void = {}

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isHoverSuppressed) private var isHoverSuppressed

    var body: some View {
        Group {
            if !isEditing && !attachment.isUploadIncomplete {
                viewingRow
            } else {
                managementRow
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
        .background {
            Rectangle()
                .fill(
                    isHovered && !isEditing && !attachment.isUploadIncomplete
                        ? Color.primary.opacity(Opacity.fieldHover(contrast))
                        : Color.clear
                )
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            optionalAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering && !isHoverSuppressed
            }
        }
        .onChange(of: isHoverSuppressed) { _, suppressed in
            if suppressed { isHovered = false }
        }
        .accessibilityIdentifier(AccessibilityID.Attachment.row(attachment.id))
    }

    // MARK: - Rows

    @ViewBuilder
    private var viewingRow: some View {
        HStack(spacing: Spacing.fieldActionGap) {
            Button {
                onPreview()
            } label: {
                HStack(spacing: Spacing.headerGap) {
                    attachmentLabel
                    Spacer()
                    if isHovered {
                        Text("Preview")
                            .font(Typography.utility.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.accentColor)
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Preview attachment")
            .accessibilityIdentifier(AccessibilityID.Attachment.openButton(attachment.id))

            Menu {
                Button {
                    onSaveToDisk()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityIdentifier(AccessibilityID.Attachment.saveButton(attachment.id))
            } label: {
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(Color.accentColor)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Attachment actions")
        }
    }

    private var managementRow: some View {
        HStack(alignment: .center, spacing: Spacing.headerGap) {
            attachmentLabel
            Spacer()
            if attachment.isUploadIncomplete {
                if isEditing {
                    incompleteActions
                } else {
                    incompleteIndicator
                }
            } else {
                deleteButton
            }
        }
    }

    private var attachmentLabel: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
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
    }

    private var deleteButton: some View {
        Button { onDelete() } label: {
            Image(systemName: "trash")
                .imageScale(.medium)
                .foregroundStyle(Color.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove attachment")
        .accessibilityIdentifier(AccessibilityID.Attachment.deleteButton(attachment.id))
    }

    // MARK: - Upload-incomplete indicator (task 6d.1)

    private var incompleteIndicator: some View {
        Label("Upload incomplete", systemImage: "exclamationmark.triangle")
            .font(Typography.utility)
            .foregroundStyle(.orange)
    }

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
