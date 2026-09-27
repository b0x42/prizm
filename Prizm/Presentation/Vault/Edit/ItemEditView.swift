import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ItemEditView

/// Form used inline for existing items and item creation.
///
/// The header exposes Cancel/Discard and Save actions inside the detail pane.
///
/// Keyboard shortcuts:
/// - ⌘S: Save (wired via `.keyboardShortcut` on the Save button)
/// - ⌘E: No-op (sheet is already open; handled in ItemDetailView)
/// - Esc: Triggers the same discard logic as the Discard button (via `.onExitCommand`)
struct ItemEditView: View {

    @ObservedObject var viewModel: ItemEditViewModel

    /// Called after save, discard, or vault lock asks the enclosing presentation to close.
    let onClose: () -> Void
    var closeTrigger: Int = 0
    var onCloseRequestCancelled: (() -> Void)? = nil

    /// Whether the discard confirmation alert is currently showing.
    @State private var showingDiscardAlert = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 0) {
            formHeader

            // Error banner - shown when a save fails; dismisses on retry.
            if let error = viewModel.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(Typography.fieldValue)
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(Opacity.errorBanner(contrast)))
                .accessibilityIdentifier(AccessibilityID.Edit.errorBanner)
            }

            // Name field - always the first editable field regardless of item type (spec §3.1).
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $viewModel.draft.name)
                    .font(Typography.pageTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.top, Spacing.pageTop)
                    .padding(.bottom, 4)

                // Live validation: shown immediately when Name field becomes empty (spec §3.2).
                if let nameError = viewModel.nameValidationError {
                    Text(nameError)
                        .font(Typography.utility)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Spacing.pageMargin)
                }
            }
            .padding(.bottom, Spacing.pageHeaderBottom)

            // Collection picker - shown for org items (replaces folder picker).
            // Folder picker - shown for personal items when folders exist.
            if viewModel.draft.organizationId != nil {
                // Org item: collection picker
                let orgCollections = viewModel.collections.filter {
                    $0.organizationId == viewModel.draft.organizationId
                }
                if !orgCollections.isEmpty {
                    // Single-collection picker for this org. For items already assigned to
                    // multiple collections, extra collection IDs (outside this org) are
                    // preserved on save; only the selected collection within this org changes.
                    let orgCollectionIds = Set(orgCollections.map(\.id))
                    let selectedCollection = Binding<String?>(
                        get: {
                            viewModel.draft.collectionIds.first { orgCollectionIds.contains($0) }
                        },
                        set: { newId in
                            // Replace only the collection IDs that belong to this org;
                            // preserve any IDs from other orgs (should not exist in practice
                            // but guards against cross-org data loss).
                            let otherIds = viewModel.draft.collectionIds.filter { !orgCollectionIds.contains($0) }
                            viewModel.draft.collectionIds = otherIds + (newId.map { [$0] } ?? [])
                        }
                    )
                    DetailSectionCard("Collection") {
                        HStack {
                            SearchableSelect(
                                title: "Collection",
                                selection: selectedCollection,
                                options: collectionOptions(orgCollections),
                                displaysLabel: false
                            )
                            Spacer()
                        }
                        .padding(.vertical, Spacing.rowVertical)
                        .padding(.horizontal, Spacing.rowHorizontal)
                    }
                }
            } else if !viewModel.folders.isEmpty {
                DetailSectionCard("Folder") {
                    HStack {
                        SearchableSelect(
                            title: "Folder",
                            selection: $viewModel.draft.folderId,
                            options: folderOptions,
                            displaysLabel: false
                        )
                        Spacer()
                    }
                    .padding(.vertical, Spacing.rowVertical)
                    .padding(.horizontal, Spacing.rowHorizontal)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Per-type edit form.
                    typeEditForm

                    if viewModel.isEditing {
                        EditableAttachmentsSection(
                            attachments: viewModel.attachments,
                            pendingAttachments: viewModel.pendingAttachments,
                            onAdd: { viewModel.selectAttachments() },
                            onRemoveAttachment: { viewModel.removeAttachment($0) },
                            onRemovePendingAttachment: { viewModel.removePendingAttachment(id: $0) },
                            onDropFiles: { viewModel.stageAttachments($0) }
                        )
                    }

                    customFieldsEditForm
                }
            }
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissFieldFocus()
                    }
            }
        }
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissFieldFocus()
                }
        }
        // Esc key invokes the same discard logic as the Discard button (spec §8.3).
        .onExitCommand {
            handleDiscard()
        }
        // Discard confirmation alert (spec §8.3).
        .alert("Discard Your Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) {
                viewModel.discard()
            }
            Button("Continue Editing", role: .cancel) {
                onCloseRequestCancelled?()
            }
        } message: {
            Text("You'll lose the changes you've made to this item. Continue editing to go back and save.")
        }
        // Close the active inline or sheet presentation after save/discard/vault lock.
        .onChange(of: viewModel.isDismissed) { _, dismissed in
            if dismissed { onClose() }
        }
        .onChange(of: closeTrigger) {
            handleDiscard()
        }
    }

    private var folderOptions: [SearchableSelectOption<String?>] {
        [
            SearchableSelectOption(value: nil, title: "None", systemImage: "tray")
        ] + viewModel.folders.map { folder in
            SearchableSelectOption(
                value: Optional(folder.id),
                title: folder.name,
                systemImage: "folder"
            )
        }
    }

    private func collectionOptions(
        _ collections: [OrgCollection]
    ) -> [SearchableSelectOption<String?>] {
        [
            SearchableSelectOption(value: nil, title: "None", systemImage: "tray")
        ] + collections.map { collection in
            SearchableSelectOption(
                value: Optional(collection.id),
                title: collection.name,
                systemImage: "square.stack"
            )
        }
    }

    private var formHeader: some View {
        HStack(spacing: Spacing.headerGap) {
            ItemLocationBreadcrumb(
                vaultName: viewModel.draft.organizationId.map { organizationID in
                    viewModel.organizations.first {
                        $0.id == organizationID
                    }?.name ?? "Organization"
                } ?? "My Vault",
                isPersonalVault: viewModel.draft.organizationId == nil,
                folderName: viewModel.folders.first {
                    $0.id == viewModel.draft.folderId
                }?.name,
                itemType: itemType
            )

            Spacer()

            Label(
                viewModel.isEditing ? "Editing" : "New Item",
                systemImage: viewModel.isEditing ? "pencil" : "plus"
            )
                .font(Typography.progressLabel)
                .accessibilityAddTraits(.isHeader)
            discardButton
            saveButton
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, Spacing.bannerVertical)
        .background(Color.accentColor.opacity(Opacity.editingBanner(contrast)))
    }

    private var itemType: ItemType {
        switch viewModel.draft.content {
        case .login:      return .login
        case .card:       return .card
        case .identity:   return .identity
        case .secureNote: return .secureNote
        case .sshKey:     return .sshKey
        }
    }

    private var discardButton: some View {
        Button(viewModel.isEditing ? "Cancel" : "Discard") {
            handleDiscard()
        }
        .disabled(viewModel.isSaving)
        .keyboardShortcut(.cancelAction)
        .help("Discard changes (Esc)")
        .accessibilityIdentifier(AccessibilityID.Edit.discardButton)
    }

    private var saveButton: some View {
        Button(viewModel.isSaving ? "Saving…" : "Save") {
            viewModel.save()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave)
        .keyboardShortcut("s", modifiers: .command)
        .accessibilityIdentifier(AccessibilityID.Edit.saveButton)
    }

    // MARK: - Per-type dispatch

    @ViewBuilder
    private var typeEditForm: some View {
        switch viewModel.draft.content {
        case .login(let content):
            // Use a local binding projected from the draft's associated value.
            LoginEditForm(
                draft: Binding(
                    get:  {
                        guard case .login(let c) = viewModel.draft.content else { return content }
                        return c
                    },
                    set:  { newContent in viewModel.draft.content = .login(newContent) }
                )
            )

        case .card(let content):
            CardEditForm(draft: Binding(
                get:  {
                    guard case .card(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .card(newContent) }
            ))

        case .identity(let content):
            IdentityEditForm(draft: Binding(
                get:  {
                    guard case .identity(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .identity(newContent) }
            ))

        case .secureNote(let content):
            SecureNoteEditForm(draft: Binding(
                get:  {
                    guard case .secureNote(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .secureNote(newContent) }
            ))

        case .sshKey(let content):
            SSHKeyEditForm(draft: Binding(
                get:  {
                    guard case .sshKey(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .sshKey(newContent) }
            ))
        }
    }

    private var customFieldsEditForm: some View {
        CustomFieldsEditSection(fields: Binding(
            get: { viewModel.draft.content.customFields },
            set: { viewModel.draft.content.customFields = $0 }
        ), linkedFieldOptions: linkedFieldOptions)
    }

    private var linkedFieldOptions: [LinkedFieldId] {
        switch viewModel.draft.content {
        case .login:
            [.loginUsername, .loginPassword]
        case .card:
            [
                .cardCardholderName, .cardExpMonth, .cardExpYear, .cardCode,
                .cardBrand, .cardNumber
            ]
        case .identity:
            [
                .identityTitle, .identityMiddleName, .identityAddress1,
                .identityAddress2, .identityAddress3, .identityCity,
                .identityState, .identityPostalCode, .identityCountry,
                .identityCompany, .identityEmail, .identityPhone, .identitySsn,
                .identityUsername, .identityPassportNumber, .identityLicenseNumber,
                .identityFirstName, .identityLastName, .identityFullName
            ]
        case .secureNote, .sshKey:
            []
        }
    }

    // MARK: - Discard logic

    /// Handles both the Discard button press and the Esc key.
    ///
    /// - If no changes have been made: dismiss immediately without a prompt (spec §8.3 "no changes" scenario).
    /// - If unsaved changes exist: show the confirmation alert first (spec §8.3 "with changes" scenario).
    private func handleDiscard() {
        if viewModel.hasChanges {
            showingDiscardAlert = true
        } else {
            viewModel.discard()
        }
    }

    /// SwiftUI on macOS keeps a TextField as first responder after background clicks.
    /// AppKit is used narrowly here because SwiftUI has no parent-level action that can
    /// clear focus owned by independent descendant `FocusState` values.
    private func dismissFieldFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

private extension DraftItemContent {
    var customFields: [DraftCustomField] {
        get {
            switch self {
            case .login(let content): content.customFields
            case .card(let content): content.customFields
            case .identity(let content): content.customFields
            case .secureNote(let content): content.customFields
            case .sshKey(let content): content.customFields
            }
        }
        set {
            switch self {
            case .login(var content):
                content.customFields = newValue
                self = .login(content)
            case .card(var content):
                content.customFields = newValue
                self = .card(content)
            case .identity(var content):
                content.customFields = newValue
                self = .identity(content)
            case .secureNote(var content):
                content.customFields = newValue
                self = .secureNote(content)
            case .sshKey(var content):
                content.customFields = newValue
                self = .sshKey(content)
            }
        }
    }
}

private struct EditableAttachmentsSection: View {
    let attachments: [Attachment]
    let pendingAttachments: [ItemEditViewModel.PendingAttachment]
    let onAdd: () -> Void
    let onRemoveAttachment: (Attachment) -> Void
    let onRemovePendingAttachment: (UUID) -> Void
    let onDropFiles: ([URL]) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        DetailSectionCard("Attachments") {
            VStack(spacing: 0) {
                if attachments.isEmpty && pendingAttachments.isEmpty {
                    Text("No attachments")
                        .font(Typography.fieldLabel)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.rowHorizontal)
                        .padding(.vertical, Spacing.rowVertical)
                } else {
                    ForEach(attachments) { attachment in
                        attachmentRow(
                            fileName: attachment.fileName,
                            sizeName: attachment.sizeName,
                            status: nil
                        ) {
                            onRemoveAttachment(attachment)
                        }
                        if attachment.id != attachments.last?.id || !pendingAttachments.isEmpty {
                            Divider()
                        }
                    }

                    ForEach(pendingAttachments) { pending in
                        attachmentRow(
                            fileName: pending.fileName,
                            sizeName: pending.sizeName,
                            status: "Pending upload"
                        ) {
                            onRemovePendingAttachment(pending.id)
                        }
                        if pending.id != pendingAttachments.last?.id {
                            Divider()
                        }
                    }
                }

                Divider()

                Button(action: onAdd) {
                    Label("Add Attachment", systemImage: "paperclip")
                        .font(Typography.fieldValue)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.rowHorizontal)
                .padding(.vertical, Spacing.rowVertical)
                .accessibilityLabel("Add Attachment")
                .accessibilityIdentifier(AccessibilityID.Attachment.addButton)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                .stroke(Color.accentColor, lineWidth: 2)
                .opacity(isDropTargeted ? 1 : 0)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            extractURLs(from: providers)
            return true
        }
    }

    private func attachmentRow(
        fileName: String,
        sizeName: String,
        status: String?,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Spacing.headerGap) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
                Text(fileName)
                    .font(Typography.fieldValue)
                    .lineLimit(1)
                HStack(spacing: Spacing.fieldActionGap) {
                    Text(sizeName)
                    if let status {
                        Text(status)
                            .foregroundStyle(.tint)
                    }
                }
                .font(Typography.listSubtitle)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(fileName)")
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .padding(.vertical, Spacing.rowVertical)
    }

    private func extractURLs(from providers: [NSItemProvider]) {
        Task {
            var urls: [URL] = []
            for provider in providers
                where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                let url = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                        if let data = item as? Data {
                            continuation.resume(
                                returning: URL(dataRepresentation: data, relativeTo: nil)
                            )
                        } else {
                            continuation.resume(returning: item as? URL)
                        }
                    }
                }
                if let url { urls.append(url) }
            }
            if !urls.isEmpty { onDropFiles(urls) }
        }
    }
}
