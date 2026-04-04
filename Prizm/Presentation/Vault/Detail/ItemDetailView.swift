import SwiftUI

// MARK: - ItemDetailView

/// Detail pane: type-specific content, metadata footer, edit sheet.
struct ItemDetailView: View {

    let item:              VaultItem?
    let faviconLoader:     FaviconLoader
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
    var onEditSheetChanged: ((Bool) -> Void)? = nil
    var onSoftDelete: ((String) async -> Void)? = nil
    var onRestore: ((String) async -> Void)? = nil
    var onPermanentDelete: ((String) async -> Void)? = nil
    var editTrigger: Int = 0
    var saveTrigger: Int = 0

    @State private var isEditSheetPresented = false
    @State private var editViewModel: ItemEditViewModel?

    @State private var isAddAttachmentSheetPresented = false
    @State private var addAttachmentViewModel: AttachmentAddViewModel?

    @State private var isBatchAttachmentSheetPresented = false
    @State private var batchAttachmentViewModel: AttachmentBatchViewModel?

    var body: some View {
        if let item {
            ScrollView {
                VStack(spacing: 0) {
                    if item.isDeleted { trashBanner(for: item) }

                    itemHeader(for: item)
                    typeDetailView(for: item)
                    attachmentsSection(for: item)

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
            .sheet(isPresented: $isAddAttachmentSheetPresented, onDismiss: {
                addAttachmentViewModel = nil
            }) {
                if let vm = addAttachmentViewModel {
                    AttachmentConfirmSheet(viewModel: vm, isPresented: $isAddAttachmentSheetPresented)
                }
            }
            .sheet(isPresented: $isBatchAttachmentSheetPresented, onDismiss: {
                batchAttachmentViewModel = nil
            }) {
                if let vm = batchAttachmentViewModel {
                    AttachmentBatchSheet(viewModel: vm, isPresented: $isBatchAttachmentSheetPresented)
                }
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
        .background(Color.secondary.opacity(0.1))
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
            makeRowViewModel: makeAttachmentRowViewModel.map { factory in
                { attachment in factory(item.id, attachment) }
            }
        )
    }

    private func openAddAttachmentSheet(for item: VaultItem) {
        guard !isAddAttachmentSheetPresented,
              let factory = makeAddAttachmentViewModel else { return }
        let vm = factory(item.id)
        addAttachmentViewModel = vm
        // NSOpenPanel runs modally (blocking) — present it first, then show the
        // confirmation sheet only if the user actually selected a valid file.
        vm.selectFile()
        if vm.isConfirming {
            isAddAttachmentSheetPresented = true
        } else {
            // User cancelled the panel or file was invalid — no sheet to show.
            addAttachmentViewModel = nil
        }
    }

    private func openBatchAttachmentSheet(for item: VaultItem, with urls: [URL]) {
        // Reject new drops while an upload is already in progress (task 6b.4).
        if let existing = batchAttachmentViewModel, existing.isUploading { return }
        guard !isBatchAttachmentSheetPresented,
              let factory = makeBatchAttachmentViewModel else { return }
        let vm = factory(item.id)
        vm.loadItems(from: urls)
        batchAttachmentViewModel          = vm
        isBatchAttachmentSheetPresented   = true
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
