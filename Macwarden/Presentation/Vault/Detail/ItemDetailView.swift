import SwiftUI

// MARK: - ItemDetailView

/// Detail pane: type-specific content, metadata footer, edit sheet.
struct ItemDetailView: View {

    let item:              VaultItem?
    let faviconLoader:     FaviconLoader
    let onCopy:            (String) -> Void
    let makeEditViewModel: (VaultItem) -> ItemEditViewModel
    var onEditSheetChanged: ((Bool) -> Void)? = nil
    var onSoftDelete: ((String) async -> Void)? = nil
    var onRestore: ((String) async -> Void)? = nil
    var onPermanentDelete: ((String) async -> Void)? = nil
    var editTrigger: Int = 0
    var saveTrigger: Int = 0

    @State private var isEditSheetPresented = false
    @State private var editViewModel: ItemEditViewModel?

    var body: some View {
        if let item {
            ScrollView {
                VStack(spacing: 0) {
                    if item.isDeleted { trashBanner(for: item) }

                    itemHeader(for: item)
                    typeDetailView(for: item)

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
            Text("Created \(item.creationDate.formatted(date: .abbreviated, time: .omitted))")
                .font(Typography.fieldValue)
                .foregroundStyle(.secondary)
            Text("Updated \(item.revisionDate.formatted(date: .abbreviated, time: .omitted))")
                .font(Typography.fieldValue)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.pageMargin + Spacing.rowHorizontal)
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
