import Combine
import SwiftUI

// MARK: - ItemListView

/// Middle-column list of vault items for the currently selected sidebar category (FR-040).
///
/// Items are already pre-sorted by `VaultRepositoryImpl`; this view renders them as-is.
/// An empty state message is shown when the list is empty (FR-042).
/// Each row has a context menu with a "Delete" action that moves the item to Trash.
struct ItemListView: View {

    let items:         [VaultItem]
    @Binding var selection: Set<String>
    let faviconLoader: FaviconLoader
    var searchQuery:   String? = nil
    var onClearSearch: (() -> Void)? = nil
    /// Organizations list for resolving org names shown on item rows (6.1).
    var organizations: [Organization] = []
    /// Called when the user confirms moving an item to Trash from the row context menu.
    /// Nil disables the delete context-menu action (e.g. when trash actions are unavailable).
    var onDelete: ((String) async -> Void)? = nil
    var onToggleFavorite: ((VaultItem) -> Void)? = nil
    var onAddToFavorites: (([VaultItem]) -> Void)? = nil
    var onDeleteItems: (([VaultItem]) async -> Void)? = nil
    var onEdit: ((VaultItem) -> Void)? = nil
    var makeMoveViewModel: (([VaultItem]) -> ItemTransferViewModel)? = nil
    var makeDuplicateViewModel: (([VaultItem]) -> ItemTransferViewModel)? = nil

    // Tracks which item is pending a soft-delete confirmation alert.
    @State private var itemsToDelete:   [VaultItem] = []
    @State private var showDeleteAlert: Bool       = false
    @State private var moveViewModel: ItemTransferViewModel?
    @State private var duplicateViewModel: ItemTransferViewModel?
    @State private var searchTypeFilter: ItemType?
    @State private var searchSortOrder: ItemSearchSortOrder = .nameAscending
    @Environment(\.colorSchemeContrast) private var contrast

    private var visibleItems: [VaultItem] {
        let filtered = if let searchTypeFilter {
            items.filter { $0.content.matchesItemType(searchTypeFilter) }
        } else {
            items
        }

        switch searchSortOrder {
        case .nameAscending:
            return filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .nameDescending:
            return filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        }
    }

    private var sections: [(letter: String, items: [VaultItem])] {
        let grouped = Dictionary(grouping: visibleItems) { item in
            let first = item.name.first.map { String($0).uppercased() } ?? "#"
            return first.first?.isLetter == true ? first : "#"
        }
        return grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return false }
            if rhs.key == "#" { return true }
            switch searchSortOrder {
            case .nameAscending:
                return lhs.key < rhs.key
            case .nameDescending:
                return lhs.key > rhs.key
            }
        }.map { (letter: $0.key, items: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if let searchQuery, !searchQuery.isEmpty {
                searchStatusBar(query: searchQuery)
            }

            Group {
            if visibleItems.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "tray",
                    description: Text("No items in this category.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityIdentifier(AccessibilityID.ItemList.emptyState)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        ForEach(sections, id: \.letter) { section in
                            Section(header: Text(section.letter)) {
                                ForEach(section.items, id: \.id) { item in
                                    HoverableItemListRow(
                                        item: item,
                                        faviconLoader: faviconLoader,
                                        searchQuery: searchQuery,
                                        orgName: orgName(for: item),
                                        isEmphasized: selection.contains(item.id)
                                    )
                                        .tag(item.id)
                                        .id(item.id)
                                        .draggable(item.id)
                                        .accessibilityIdentifier(AccessibilityID.ItemList.row(item.id))
                                        .contextMenu {
                                            let contextItems = contextItems(for: item)
                                            if contextItems.count > 1 {
                                                if let onAddToFavorites {
                                                    Button("Add to Favorites") {
                                                        adoptContextSelection(contextItems)
                                                        onAddToFavorites(contextItems)
                                                    }
                                                }
                                                if let makeMoveViewModel {
                                                    Button("Move \(contextItems.count) Items…") {
                                                        adoptContextSelection(contextItems)
                                                        moveViewModel = makeMoveViewModel(contextItems)
                                                    }
                                                }
                                                if let makeDuplicateViewModel {
                                                    Button("Duplicate \(contextItems.count) Items…") {
                                                        adoptContextSelection(contextItems)
                                                        duplicateViewModel = makeDuplicateViewModel(contextItems)
                                                    }
                                                }
                                                Divider()
                                                if onDeleteItems != nil {
                                                    Button("Delete \(contextItems.count) Items", role: .destructive) {
                                                        adoptContextSelection(contextItems)
                                                        itemsToDelete = contextItems
                                                        showDeleteAlert = true
                                                    }
                                                }
                                            } else {
                                                if let onEdit {
                                                    Button("Edit") {
                                                        adoptContextSelection(contextItems)
                                                        onEdit(item)
                                                    }
                                                }
                                                if let makeMoveViewModel {
                                                    Button("Move…") {
                                                        adoptContextSelection(contextItems)
                                                        moveViewModel = makeMoveViewModel(contextItems)
                                                    }
                                                }
                                                if let makeDuplicateViewModel {
                                                    Button("Duplicate…") {
                                                        adoptContextSelection(contextItems)
                                                        duplicateViewModel = makeDuplicateViewModel(contextItems)
                                                    }
                                                }
                                                Divider()
                                                if let onToggleFavorite {
                                                    Button(item.isFavorite ? "Unfavorite" : "Favorite") {
                                                        adoptContextSelection(contextItems)
                                                        onToggleFavorite(item)
                                                    }
                                                }
                                                if onDelete != nil {
                                                    Button("Delete", role: .destructive) {
                                                        adoptContextSelection(contextItems)
                                                        itemsToDelete = contextItems
                                                        showDeleteAlert = true
                                                    }
                                                }
                                            }
                                        }
                                }
                            }
                            .listSectionSeparator(.hidden)
                        }
                    }
                    .accessibilityValue("\(selection.count) item\(selection.count == 1 ? "" : "s") selected")
                    .onChange(of: selection) {
                        scrollToSelection(using: proxy)
                    }
                    .onChange(of: visibleItems.map(\.id)) {
                        scrollToSelection(using: proxy)
                    }
                    .onDeleteCommand {
                        requestSelectedItemsDeletion()
                    }
                    // Soft-delete confirmation alert - shown when the user selects "Delete"
                    // from a row context menu. The item is only moved to Trash, not permanently
                    // deleted; it can be recovered from the Trash view.
                    .alert(
                        itemsToDelete.count > 1 ? "Move \(itemsToDelete.count) Items to Trash?" : "Move to Trash?",
                        isPresented: $showDeleteAlert
                    ) {
                        Button("Move to Trash", role: .destructive) {
                            let pendingItems = itemsToDelete
                            Task {
                                if pendingItems.count == 1, let item = pendingItems.first {
                                    await onDelete?(item.id)
                                } else {
                                    await onDeleteItems?(pendingItems)
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        if let item = itemsToDelete.first, itemsToDelete.count == 1 {
                            Text("\"\(item.name)\" will be moved to Trash.")
                        } else {
                            Text("The selected items will be moved to Trash.")
                        }
                    }
                }
            }
            }
        }
        .sheet(item: $moveViewModel) { viewModel in
            MoveItemSheet(viewModel: viewModel)
        }
        .sheet(item: $duplicateViewModel) { viewModel in
            DuplicateItemSheet(viewModel: viewModel)
        }
    }

    private var filterBar: some View {
        HStack(spacing: Spacing.headerGap) {
            Menu {
                filterMenuButton(title: "All Types", systemImage: "square.grid.2x2", type: nil)
                Divider()
                ForEach(ItemType.allCases) { type in
                    filterMenuButton(title: type.displayName, systemImage: type.sfSymbol, type: type)
                }
            } label: {
                HStack(spacing: Spacing.headerGap) {
                    Image(systemName: searchTypeFilter?.sfSymbol ?? "square.grid.2x2")
                        .accessibilityHidden(true)
                    Text(searchTypeFilter?.displayName ?? "All Types")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(Typography.utility)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(
                    searchTypeFilter == nil
                        ? Color.primary
                        : DesignColor.selectedContentForeground
                )
                .padding(.horizontal, Spacing.rowHorizontal)
                .padding(.vertical, Spacing.readOnlyField)
                .background(
                    Color.accentColor.opacity(searchTypeFilter == nil ? 0 : 1),
                    in: RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                )
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Filter Items by Type")
            .accessibilityValue(searchTypeFilter?.displayName ?? "All Types")

            Spacer()

            Menu {
                Button("Name, A to Z") { searchSortOrder = .nameAscending }
                Button("Name, Z to A") { searchSortOrder = .nameDescending }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .padding(.horizontal, Spacing.rowHorizontal)
                    .padding(.vertical, Spacing.readOnlyField)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .help("Sort Items")
            .accessibilityLabel("Sort Items")
            .accessibilityValue(searchSortOrder.accessibilityName)
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .frame(height: LayoutMetrics.paneActionBarHeight)
        .background(.bar)
    }

    private func filterMenuButton(
        title: String,
        systemImage: String,
        type: ItemType?
    ) -> some View {
        Button {
            searchTypeFilter = type
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if searchTypeFilter == type {
                    Image(systemName: "checkmark")
                }
            }
        }
        .accessibilityValue(searchTypeFilter == type ? "Selected" : "Not selected")
    }

    private func searchStatusBar(query: String) -> some View {
        HStack(spacing: Spacing.headerGap) {
            Text("\(visibleItems.count) \(visibleItems.count == 1 ? "result" : "results") for “\(query)”")
                .font(Typography.fieldValue)
                .lineLimit(1)
            Spacer()
            Button {
                onClearSearch?()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Clear Search")
            .accessibilityLabel("Clear Search")
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .padding(.vertical, Spacing.rowVertical)
        .background(Color.accentColor.opacity(Opacity.searchStatusBackground(contrast)))
        .accessibilityElement(children: .contain)
    }

    /// Returns the org name for a vault item, or nil for personal items.
    private func orgName(for item: VaultItem) -> String? {
        guard let orgId = item.organizationId else { return nil }
        return organizations.first(where: { $0.id == orgId })?.name
    }

    private func contextItems(for clickedItem: VaultItem) -> [VaultItem] {
        guard selection.contains(clickedItem.id), selection.count > 1 else {
            return [clickedItem]
        }
        return visibleItems.filter { selection.contains($0.id) }
    }

    private func adoptContextSelection(_ contextItems: [VaultItem]) {
        selection = Set(contextItems.map(\.id))
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard let selectedID = visibleItems.first(where: { selection.contains($0.id) })?.id else {
            return
        }
        Task { @MainActor in
            await Task.yield()
            withAnimation {
                proxy.scrollTo(selectedID, anchor: .center)
            }
        }
    }

    private func requestSelectedItemsDeletion() {
        let selectedItems = visibleItems.filter { selection.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        guard selectedItems.count > 1 ? onDeleteItems != nil : onDelete != nil else { return }
        itemsToDelete = selectedItems
        showDeleteAlert = true
    }
}

private struct HoverableItemListRow: View {
    let item: VaultItem
    let faviconLoader: FaviconLoader
    let searchQuery: String?
    let orgName: String?
    let isEmphasized: Bool

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isHoverSuppressed) private var isHoverSuppressed

    var body: some View {
        ItemRowView(
            item: item,
            faviconLoader: faviconLoader,
            searchQuery: searchQuery,
            orgName: orgName,
            isEmphasized: isEmphasized
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                .fill(
                    isEmphasized
                        ? Color.accentColor
                        : isHovered
                            ? Color.primary.opacity(Opacity.itemRowHover(contrast))
                            : Color.clear
                )
                .padding(.horizontal, Spacing.itemHighlightHorizontalMargin)
        )
        .onHover { hovering in
            optionalAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering && !isHoverSuppressed
            }
        }
        .onChange(of: isHoverSuppressed) { _, suppressed in
            if suppressed { isHovered = false }
        }
    }
}

private enum ItemSearchSortOrder {
    case nameAscending
    case nameDescending

    var accessibilityName: String {
        switch self {
        case .nameAscending:  "Name, A to Z"
        case .nameDescending: "Name, Z to A"
        }
    }
}

// MARK: - Item transfer sheets

@MainActor
final class ItemTransferViewModel: ObservableObject, Identifiable {
    enum Operation: Equatable {
        case move
        case duplicate
    }

    enum DestinationOwner: Hashable {
        case personal
        case organization(String)
    }

    let id = UUID()
    let operation: Operation
    let items: [VaultItem]
    let folders: [Folder]
    let organizations: [Organization]
    let collections: [OrgCollection]

    @Published var name: String
    @Published var destinationOwner: DestinationOwner
    @Published var folderId: String?
    @Published var collectionId: String?
    @Published var includeAttachments = false
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isDismissed = false
    @Published private(set) var completedCount = 0
    @Published private(set) var bulkResult: VaultItemBulkTransferResult?

    private let moveUseCase: any MoveVaultItemUseCase
    private let duplicateUseCase: any DuplicateVaultItemUseCase
    private let onFinished: ([VaultItem]) -> Void
    nonisolated(unsafe) private var operationTask: Task<Void, Never>?

    init(
        operation: Operation,
        items: [VaultItem],
        folders: [Folder],
        organizations: [Organization],
        collections: [OrgCollection],
        moveUseCase: any MoveVaultItemUseCase,
        duplicateUseCase: any DuplicateVaultItemUseCase,
        onFinished: @escaping ([VaultItem]) -> Void
    ) {
        precondition(!items.isEmpty)
        self.operation = operation
        self.items = items
        self.folders = folders
        self.organizations = organizations
        self.collections = collections
        self.moveUseCase = moveUseCase
        self.duplicateUseCase = duplicateUseCase
        self.onFinished = onFinished
        let firstItem = items[0]
        self.name = firstItem.name
        self.folderId = firstItem.folderId
        self.collectionId = firstItem.collectionIds.first
        if let organizationId = firstItem.organizationId {
            self.destinationOwner = .organization(organizationId)
        } else {
            self.destinationOwner = .personal
        }
    }

    deinit {
        operationTask?.cancel()
    }

    var title: String {
        let noun = items.count == 1 ? "Item" : "\(items.count) Items"
        return operation == .move ? "Move \(noun)" : "Duplicate \(noun)"
    }

    var actionTitle: String {
        operation == .move ? "Move" : "Duplicate"
    }

    var canSubmit: Bool {
        !isWorking && (
            bulkResult != nil
                || operation == .move
                || items.count > 1
                || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    var item: VaultItem { items[0] }

    var destinationCollections: [OrgCollection] {
        guard case .organization(let organizationId) = destinationOwner else { return [] }
        return collections.filter { $0.organizationId == organizationId }
    }

    var isCrossOwnerMove: Bool {
        guard operation == .move else { return false }
        let organizationIds = Set(items.map(\.organizationId))
        if organizationIds.count > 1 { return true }
        switch destinationOwner {
        case .personal:
            return items.contains { $0.organizationId != nil }
        case .organization(let id):
            return items.contains { $0.organizationId != id }
        }
    }

    var destination: VaultItemDestination {
        switch destinationOwner {
        case .personal:
            return .personal(folderId: folderId)
        case .organization(let id):
            return .organization(id: id, collectionId: collectionId)
        }
    }

    func destinationOwnerChanged() {
        folderId = nil
        collectionId = nil
    }

    func submit() {
        guard canSubmit else { return }
        if bulkResult != nil {
            isDismissed = true
            return
        }
        operationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            isWorking = true
            errorMessage = nil
            completedCount = 0
            do {
                if items.count > 1 {
                    let result: VaultItemBulkTransferResult
                    let progress: @MainActor @Sendable (Int) -> Void = { [weak self] count in
                        self?.completedCount = count
                    }
                    switch operation {
                    case .move:
                        result = await moveUseCase.execute(
                            items: items,
                            destination: destination,
                            progress: progress
                        )
                    case .duplicate:
                        result = await duplicateUseCase.execute(
                            items: items,
                            destination: destination,
                            includeAttachments: includeAttachments,
                            progress: progress
                        )
                    }
                    isWorking = false
                    onFinished(result.succeeded)
                    if result.failures.isEmpty {
                        isDismissed = true
                    } else {
                        bulkResult = result
                        AccessibilityNotification.Announcement(
                            "\(result.succeeded.count) completed, \(result.failures.count) failed"
                        ).post()
                    }
                } else {
                    let result: VaultItem
                    switch operation {
                    case .move:
                        result = try await moveUseCase.execute(item: item, destination: destination)
                    case .duplicate:
                        result = try await duplicateUseCase.execute(
                            item: item,
                            name: name,
                            destination: destination,
                            includeAttachments: includeAttachments
                        )
                    }
                    isWorking = false
                    onFinished([result])
                    isDismissed = true
                }
            } catch is CancellationError {
                isWorking = false
                onFinished([])
                return
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
                onFinished([])
            }
        }
    }

    func cancel() {
        operationTask?.cancel()
        isDismissed = true
    }
}

struct MoveItemSheet: View {
    @ObservedObject var viewModel: ItemTransferViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ItemTransferSheetContent(viewModel: viewModel)
            .onChange(of: viewModel.isDismissed) { _, dismissed in
                if dismissed { dismiss() }
            }
    }
}

struct DuplicateItemSheet: View {
    @ObservedObject var viewModel: ItemTransferViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ItemTransferSheetContent(viewModel: viewModel)
            .onChange(of: viewModel.isDismissed) { _, dismissed in
                if dismissed { dismiss() }
            }
    }
}

private struct ItemTransferSheetContent: View {
    @ObservedObject var viewModel: ItemTransferViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.headerGap) {
                Image(systemName: viewModel.operation == .move ? "folder.badge.arrow.forward" : "plus.square.on.square")
                    .font(Typography.screenIcon)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(viewModel.title)
                    .font(Typography.screenHeading)
                Text(viewModel.items.count == 1 ? viewModel.item.name : "\(viewModel.items.count) selected items")
                    .font(Typography.fieldValue)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, Spacing.pageTop)
            .padding(.horizontal, Spacing.pageMargin)

            Form {
                if viewModel.operation == .duplicate {
                    Section("Copy") {
                        if viewModel.items.count == 1 {
                            TextField("Name", text: $viewModel.name)
                        } else {
                            Text("Copies keep their original names.")
                                .font(Typography.utility)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("Include attachments", isOn: $viewModel.includeAttachments)
                            .disabled(!viewModel.items.contains { !$0.attachments.isEmpty })
                            .accessibilityValue(viewModel.includeAttachments ? "Included" : "Not included")
                        if viewModel.items.contains(where: { !$0.attachments.isEmpty }) {
                            Text("Files are briefly decrypted in memory, then re-encrypted for the destination. This may take longer.")
                                .font(Typography.utility)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Destination") {
                    SearchableSelect(
                        title: "Vault",
                        selection: $viewModel.destinationOwner,
                        options: vaultOptions
                    )
                    .onChange(of: viewModel.destinationOwner) {
                        viewModel.destinationOwnerChanged()
                    }

                    switch viewModel.destinationOwner {
                    case .personal:
                        SearchableSelect(
                            title: "Folder",
                            selection: $viewModel.folderId,
                            options: folderOptions
                        )
                    case .organization:
                        SearchableSelect(
                            title: "Collection",
                            selection: $viewModel.collectionId,
                            options: collectionOptions
                        )
                    }
                }

                if viewModel.isCrossOwnerMove {
                    Section {
                        Label(
                            "A secure copy, including all attachments, is created first. The original moves to Trash only after everything succeeds.",
                            systemImage: "shield.lefthalf.filled"
                        )
                        .font(Typography.utility)
                        .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier(AccessibilityID.Transfer.error)
                    }
                }

                if let result = viewModel.bulkResult {
                    Section("Completed with Issues") {
                        Text("\(result.succeeded.count) completed · \(result.failures.count) failed")
                            .font(Typography.fieldValue)
                        ForEach(result.failures) { failure in
                            VStack(alignment: .leading, spacing: Spacing.badgeVertical) {
                                Text(failure.itemName)
                                    .font(Typography.fieldValue)
                                Text(failure.message)
                                    .font(Typography.utility)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel") {
                    viewModel.cancel()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                if viewModel.isWorking {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        if viewModel.items.count > 1 {
                            Text("\(viewModel.completedCount) / \(viewModel.items.count)")
                                .font(Typography.utility)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(viewModel.actionTitle) in progress")
                    .accessibilityValue("\(viewModel.completedCount) of \(viewModel.items.count)")
                }
                Button(viewModel.bulkResult != nil ? "Close" : viewModel.isWorking ? "\(viewModel.actionTitle)…" : viewModel.actionTitle) {
                    viewModel.submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canSubmit)
                .accessibilityIdentifier(AccessibilityID.Transfer.confirm)
            }
            .padding(Spacing.pageMargin)
        }
        .frame(
            minWidth: TransferSheetMetrics.minimumWidth,
            minHeight: TransferSheetMetrics.minimumHeight
        )
        .onChange(of: viewModel.errorMessage) { _, message in
            if let message {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    private var vaultOptions: [SearchableSelectOption<ItemTransferViewModel.DestinationOwner>] {
        [
            SearchableSelectOption(
                value: .personal,
                title: "My Vault",
                systemImage: "person.crop.circle"
            )
        ] + viewModel.organizations.map { organization in
            SearchableSelectOption(
                value: .organization(organization.id),
                title: organization.name,
                systemImage: "building.2"
            )
        }
    }

    private var folderOptions: [SearchableSelectOption<String?>] {
        [
            SearchableSelectOption(
                value: nil,
                title: "No Folder",
                systemImage: "tray"
            )
        ] + viewModel.folders.map { folder in
            SearchableSelectOption(
                value: Optional(folder.id),
                title: folder.name,
                systemImage: "folder"
            )
        }
    }

    private var collectionOptions: [SearchableSelectOption<String?>] {
        [
            SearchableSelectOption(
                value: nil,
                title: "Default Collection",
                systemImage: "tray"
            )
        ] + viewModel.destinationCollections.map { collection in
            SearchableSelectOption(
                value: Optional(collection.id),
                title: collection.name,
                systemImage: "square.stack"
            )
        }
    }
}

private enum TransferSheetMetrics {
    static let minimumWidth: CGFloat = 520
    static let minimumHeight: CGFloat = 480
}
