import SwiftUI

// MARK: - ItemDetailView

/// Detail pane: type-specific content, metadata footer, edit sheet.
struct ItemDetailView: View {

    let item:              VaultItem?
    let faviconLoader:     FaviconLoader
    let folders:           [Folder]
    let onCopy:            (String) -> Void
    let makeEditViewModel: (VaultItem) -> ItemEditViewModel
    /// Factory that creates an `AttachmentAddViewModel` for the given cipher ID.
    /// Injected from `AppContainer` so `ItemDetailView` stays decoupled from Data layer.
    var makeAddAttachmentViewModel: ((String) -> AttachmentAddViewModel)? = nil
    /// Factory that creates an `AttachmentBatchViewModel` for a drag-and-drop upload.
    var makeBatchAttachmentViewModel: ((String) -> AttachmentBatchViewModel)? = nil
    /// Factory for `AttachmentRowViewModel` — passed to `AttachmentsSectionView` so each
    /// row gets its own ViewModel instance (Constitution §II decoupling).
    var makeAttachmentRowViewModel: ((String, Attachment) -> AttachmentRowViewModel)? = nil
    /// Called when an attachment upload sheet is dismissed, whether the upload
    /// succeeded or was cancelled. The parent view uses this to refresh `itemSelection`
    /// so the attachment list in the detail pane reflects the new server state.
    var onAttachmentsChanged: (() -> Void)? = nil
    var onEditSheetChanged: ((Bool) -> Void)? = nil
    var onSoftDelete: ((String) async -> Void)? = nil
    var onRestore: ((String) async -> Void)? = nil
    var onPermanentDelete: ((String) async -> Void)? = nil
    var editTrigger: Int = 0
    var saveTrigger: Int = 0

    @State private var isEditSheetPresented = false
    @State private var editViewModel: ItemEditViewModel?

    // Both add-attachment and batch sheets use .sheet(item:) so SwiftUI receives the
    // ViewModel directly — eliminating the race where the sheet body evaluated before
    // the optional ViewModel state was committed, producing a blank sheet window.
    @State private var addAttachmentViewModel: AttachmentAddViewModel?
    @State private var isPickingAttachment = false   // drives spinner while NSOpenPanel blocks

    @State private var batchAttachmentViewModel: AttachmentBatchViewModel?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if let item {
            ScrollView {
                VStack(spacing: 0) {
                    if item.isDeleted { trashBanner(for: item) }

                    itemHeader(for: item)
                    typeDetailView(for: item)
                    attachmentsSection(for: item)
                    folderRow(for: item)

                    Spacer(minLength: 20)
                    metadataFooter(for: item)
                }
            }
            .sheet(isPresented: $isEditSheetPresented, onDismiss: {
                editViewModel = nil
                onEditSheetChanged?(false)
            }) {
                if let vm = editViewModel {
                    ItemEditView(viewModel: vm, isPresented: $isEditSheetPresented)
                }
            }
            .sheet(item: $addAttachmentViewModel, onDismiss: {
                onAttachmentsChanged?()
            }) { vm in
                AttachmentConfirmSheet(viewModel: vm)
            }
            .sheet(item: $batchAttachmentViewModel, onDismiss: {
                onAttachmentsChanged?()
            }) { vm in
                AttachmentBatchSheet(viewModel: vm)
            }
            .onChange(of: editTrigger) { if !item.isDeleted { openEditSheet(for: item) } }
            .onChange(of: saveTrigger) { editViewModel?.save() }
        } else {
            ContentUnavailableView(
                "No Item Selected",
                systemImage: "square.dashed",
                description: Text("Select an item from the list.")
            )
            .accessibilityIdentifier(AccessibilityID.Detail.emptyState)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func itemHeader(for item: VaultItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            FaviconView(
                domain:   primaryDomain(for: item),
                itemType: itemType(for: item),
                loader:   faviconLoader,
                size:     36
            )
            Text(item.name.isEmpty ? " " : item.name)
                .font(Typography.pageTitle)
                .accessibilityIdentifier(AccessibilityID.Detail.itemName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.pageTop)
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.bottom, Spacing.pageHeaderBottom)
    }

    @ViewBuilder
    private func folderRow(for item: VaultItem) -> some View {
        if let folderId = item.folderId,
           let folder = folders.first(where: { $0.id == folderId }) {
            DetailSectionCard("Folder") {
                FieldRowView(label: "", value: folder.name, itemId: item.id)
            }
        }
    }

    private func metadataFooter(for item: VaultItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("Updated:")
                    .frame(width: 70, alignment: .leading)
                Text(item.revisionDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
            }
            HStack(spacing: 0) {
                Text("Created:")
                    .frame(width: 70, alignment: .leading)
                Text(item.creationDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
            }
        }
        .font(Typography.fieldValue)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.top, Spacing.cardTop)
        .padding(.bottom, Spacing.cardBottom)
    }

    @ViewBuilder
    private func trashBanner(for item: VaultItem) -> some View {
        HStack(spacing: Spacing.headerGap) {
            Image(systemName: "trash").foregroundStyle(.secondary)
            Text("This item is in Trash.").font(Typography.bannerText).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, Spacing.headerGap)
        .background(Color.secondary.opacity(Opacity.trashBanner(contrast)))
        .accessibilityIdentifier(AccessibilityID.Trash.statusBanner)
    }

    // MARK: - Edit sheet

    private func openEditSheet(for item: VaultItem) {
        guard !isEditSheetPresented else { return }
        editViewModel = makeEditViewModel(item)
        isEditSheetPresented = true
        onEditSheetChanged?(true)
    }

    // MARK: - Helpers

    private func primaryDomain(for item: VaultItem) -> String? {
        guard case .login(let l) = item.content, let first = l.uris.first else { return nil }
        return URL(string: first.uri)?.host
    }

    private func itemType(for item: VaultItem) -> ItemType {
        switch item.content {
        case .login:      .login
        case .card:       .card
        case .identity:   .identity
        case .secureNote: .secureNote
        case .sshKey:     .sshKey
        }
    }

    // MARK: - Attachments section

    @ViewBuilder
    private func attachmentsSection(for item: VaultItem) -> some View {
        AttachmentsSectionView(
            attachments:      item.attachments,
            onAddTapped:      { openAddAttachmentSheet(for: item) },
            onDropFiles:      { urls in openBatchAttachmentSheet(for: item, with: urls) },
            isPicking:        isPickingAttachment,
            makeRowViewModel: makeAttachmentRowViewModel.map { factory in
                { [onAttachmentsChanged] attachment in
                    let vm = factory(item.id, attachment)
                    vm.onAttachmentChanged = onAttachmentsChanged
                    return vm
                }
            }
        )
    }

    private func openAddAttachmentSheet(for item: VaultItem) {
        guard addAttachmentViewModel == nil, !isPickingAttachment,
              let factory = makeAddAttachmentViewModel else { return }
        let vm = factory(item.id)
        // isPickingAttachment drives the spinner independently of the ViewModel reference.
        // addAttachmentViewModel is only set atomically with isAddAttachmentSheetPresented so
        // the sheet body always evaluates with non-nil data on its first render pass —
        // eliminating the blank-sheet flash that occurred when the two writes were separated
        // by the NSOpenPanel session.
        isPickingAttachment = true
        Task {
            await vm.selectFile()
            isPickingAttachment = false
            if vm.isConfirming {
                // Single file — show the per-file confirm sheet.
                addAttachmentViewModel = vm
            } else if !vm.pickedURLs.isEmpty, let batchFactory = makeBatchAttachmentViewModel {
                // Multiple files — route to the batch sheet that already handles N files.
                let batchVM = batchFactory(item.id)
                batchVM.loadItems(from: vm.pickedURLs)
                batchAttachmentViewModel = batchVM
            }
        }
    }

    private func openBatchAttachmentSheet(for item: VaultItem, with urls: [URL]) {
        // Reject new drops while an upload is already in progress (task 6b.4).
        if let existing = batchAttachmentViewModel, existing.isUploading { return }
        guard batchAttachmentViewModel == nil,
              let factory = makeBatchAttachmentViewModel else { return }
        let vm = factory(item.id)
        vm.loadItems(from: urls)
        batchAttachmentViewModel = vm   // non-nil → .sheet(item:) presents immediately
    }

    @ViewBuilder
    private func typeDetailView(for item: VaultItem) -> some View {
        switch item.content {
        case .login(let l):      LoginDetailView(item: item, login: l, onCopy: onCopy)
        case .card(let c):       CardDetailView(item: item, card: c, onCopy: onCopy)
        case .identity(let i):   IdentityDetailView(item: item, identity: i, onCopy: onCopy)
        case .secureNote(let n): SecureNoteDetailView(item: item, secureNote: n, onCopy: onCopy)
        case .sshKey(let k):     SSHKeyDetailView(item: item, sshKey: k, onCopy: onCopy)
        }
    }
}
