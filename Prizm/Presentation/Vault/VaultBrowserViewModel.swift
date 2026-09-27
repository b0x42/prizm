import AppKit
import Combine
import Foundation
import os.log

enum VaultNavigationContext: Hashable {
    case allVaults
    case personal
    case organization(String)
}

// MARK: - VaultBrowserViewModel

/// ViewModel for the three-pane vault browser (User Story 3).
///
/// Responsibilities:
///   - Manages sidebar selection and item list content
///   - Runs in-memory search filter in real time (FR-012)
///   - Provides clipboard copy with 30-second auto-clear (FR-011, SC-004)
///   - Surfaces the last-synced timestamp for the toolbar (FR-037, FR-041)
///   - Tracks and dismisses the sync error banner (FR-049)
@MainActor
final class VaultBrowserViewModel: ObservableObject {

    // MARK: - Published state

    @Published var sidebarSelection: SidebarSelection = .allItems {
        didSet {
            if oldValue != sidebarSelection {
                if isGlobalSearch { deactivateGlobalSearch(restoreSelection: false) }
                itemSelection = nil
                refreshItems(showLoadingIndicator: true)
            }
        }
    }

    @Published var itemSelection: VaultItem? {
        didSet {
            guard let itemSelection else {
                selectedItemIDs = []
                return
            }
            if !selectedItemIDs.contains(itemSelection.id) {
                selectedItemIDs = [itemSelection.id]
            }
        }
    }
    @Published private(set) var selectedItemIDs: Set<String> = []
    @Published var navigationContext: VaultNavigationContext = .allVaults {
        didSet {
            guard oldValue != navigationContext else { return }
            if isGlobalSearch {
                deactivateGlobalSearch(restoreSelection: false)
            }
            itemSelection = nil
            if sidebarSelection == .allItems {
                refreshItems(showLoadingIndicator: true)
            } else {
                sidebarSelection = .allItems
            }
            refreshCounts()
        }
    }
    @Published var searchQuery:   String = "" {
        didSet {
            if !searchQuery.isEmpty, oldValue != searchQuery {
                itemSelection = nil
            }
            Task { @MainActor in refreshItems() }
        }
    }
    @Published private(set) var searchSuggestions: [VaultItem] = []

    /// When true, search queries are scoped to `.allItems` regardless of sidebar selection.
    @Published private(set) var isGlobalSearch: Bool = false

    /// The sidebar selection that was active before global search was activated.
    private(set) var previousSelection: SidebarSelection?

    @Published private(set) var displayedItems: [VaultItem] = []
    @Published private(set) var isLoadingItems = false
    @Published private(set) var itemCounts: [SidebarSelection: Int] = [:]
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var organizations: [Organization] = []
    @Published private(set) var collections: [OrgCollection] = []

    var selectedFolderId: String? {
        if case .folder(let id) = sidebarSelection { return id }
        return nil
    }

    /// Non-nil when the active sidebar selection is a specific collection.
    /// Used to pre-fill the collection picker when creating items from a collection context (task 5.9).
    var selectedCollectionId: String? {
        if case .collection(let id) = sidebarSelection { return id }
        return nil
    }
    @Published private(set) var lastSyncedAt: Date?
    @Published var syncErrorMessage: String? = nil
    /// Reflects whether an inline item form is currently open. Used by `MenuBarViewModel`
    /// to enable/disable the Edit and Save menu bar actions.
    @Published private(set) var isEditingItem: Bool = false

    // MARK: - Published state (trash actions)

    /// Set when a delete, restore, or empty-trash operation fails.
    /// The Presentation layer surfaces this as an alert.
    @Published var actionError: String? = nil

    /// Set to a non-nil `ItemType` to present the inline creation form for that type.
    /// Automatically cleared if the user switches to Trash.
    @Published var createItemType: ItemType? = nil {
        didSet {
            if sidebarSelection == .trash { createItemType = nil }
        }
    }

    // MARK: - Dependencies

    private let vault:                  any VaultRepository
    private let search:                 any SearchVaultUseCase
    private let deleteUseCase:          any DeleteVaultItemUseCase
    private let permanentDeleteUseCase: any PermanentDeleteVaultItemUseCase
    private let restoreUseCase:         any RestoreVaultItemUseCase
    private let createFolderUseCase:      any CreateFolderUseCase
    private let renameFolderUseCase:      any RenameFolderUseCase
    private let deleteFolderUseCase:      any DeleteFolderUseCase
    private let moveItemUseCase:          any MoveItemToFolderUseCase
    private let createCollectionUseCase:  any CreateCollectionUseCase
    private let renameCollectionUseCase:  any RenameCollectionUseCase
    private let deleteCollectionUseCase:  any DeleteCollectionUseCase
    private var syncTimestamp:          any SyncTimestampRepository
    private var getLastSyncDate:        any GetLastSyncDateUseCase
    private var itemRefreshGeneration = 0
    private let logger = Logger(subsystem: "com.prizm", category: "VaultBrowserViewModel")

    // MARK: - Menu bar action relay

    /// Incremented each time the "Item > Edit" menu bar action fires (spec §9.3).
    /// `ItemDetailView` uses `.onChange(of: editTrigger)` to open the edit sheet.
    /// An integer counter (rather than a Combine PassthroughSubject) keeps the relay
    /// within the async/await pattern mandated by CLAUDE.md.
    @Published private(set) var editTrigger: Int = 0

    /// Incremented each time the "Item > Save" menu bar action fires (spec §9.4).
    /// `ItemDetailView` uses `.onChange(of: saveTrigger)` to call `save()`.
    @Published private(set) var saveTrigger: Int = 0

    func triggerEdit() { editTrigger += 1 }
    func triggerEdit(item: VaultItem) {
        itemSelection = item
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.editTrigger += 1
        }
    }
    func triggerSave() { saveTrigger += 1 }

    func updateItemSelection(_ ids: Set<String>) {
        let addedIDs = ids.subtracting(selectedItemIDs)
        selectedItemIDs = ids
        guard !ids.isEmpty else {
            itemSelection = nil
            return
        }
        if let added = displayedItems.last(where: { addedIDs.contains($0.id) }) {
            itemSelection = added
        } else if itemSelection.map({ ids.contains($0.id) }) != true {
            itemSelection = displayedItems.first(where: { ids.contains($0.id) })
        }
    }

    // MARK: - Sync label refresh timer

    /// Fires every 60 seconds to re-evaluate the relative sync label while the app is open.
    /// Invalidated in `deinit` to prevent the timer outliving the ViewModel.
    // nonisolated(unsafe) is required because deinit is always nonisolated in Swift 6,
    // and Timer is non-Sendable. The timer is only mutated on MainActor, so this is safe.
    nonisolated(unsafe) private var labelRefreshTimer: Timer?

    /// Relative label derived from `lastSyncedAt`, refreshed every 60 seconds.
    @Published private(set) var syncStatusLabel: String = "Never synced"

    // MARK: - Clipboard auto-clear

    private var clipboardClearTask: Task<Void, Never>?
    private var searchSuggestionTask: Task<Void, Never>?
    private var searchSuggestionGeneration = 0

    // MARK: - Init

    init(
        vault:             any VaultRepository,
        search:            any SearchVaultUseCase,
        delete:            any DeleteVaultItemUseCase,
        permanentDelete:   any PermanentDeleteVaultItemUseCase,
        restore:           any RestoreVaultItemUseCase,
        createFolder:      any CreateFolderUseCase,
        renameFolder:      any RenameFolderUseCase,
        deleteFolder:      any DeleteFolderUseCase,
        moveItem:          any MoveItemToFolderUseCase,
        createCollection:  any CreateCollectionUseCase,
        renameCollection:  any RenameCollectionUseCase,
        deleteCollection:  any DeleteCollectionUseCase,
        syncTimestamp:     any SyncTimestampRepository,
        getLastSyncDate:   any GetLastSyncDateUseCase
    ) {
        self.vault                  = vault
        self.search                 = search
        self.deleteUseCase          = delete
        self.permanentDeleteUseCase = permanentDelete
        self.restoreUseCase         = restore
        self.createFolderUseCase    = createFolder
        self.renameFolderUseCase    = renameFolder
        self.deleteFolderUseCase    = deleteFolder
        self.moveItemUseCase        = moveItem
        self.createCollectionUseCase = createCollection
        self.renameCollectionUseCase = renameCollection
        self.deleteCollectionUseCase = deleteCollection
        self.syncTimestamp          = syncTimestamp
        self.getLastSyncDate        = getLastSyncDate
        refreshItems()
        refreshCounts()
        refreshFolders()
        refreshOrganizations()
        lastSyncedAt    = getLastSyncDate.execute()
        syncStatusLabel = lastSyncedAt.syncStatusLabel()
        startLabelRefreshTimer()
    }

    deinit {
        labelRefreshTimer?.invalidate()
        clipboardClearTask?.cancel()
        searchSuggestionTask?.cancel()
    }

    // MARK: - Timer

    private func startLabelRefreshTimer() {
        // Re-evaluate the relative label every 60 seconds so "2 minutes ago" stays accurate
        // without requiring a view reload. The timer is weak-captured to avoid a retain cycle.
        labelRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Guard against no-op updates: only assign when the label text changes,
                // avoiding unnecessary SwiftUI re-renders every 60 seconds.
                let updated = lastSyncedAt.syncStatusLabel()
                if syncStatusLabel != updated { syncStatusLabel = updated }
            }
        }
    }

    // MARK: - Actions

    /// Activates global search mode: stores the current sidebar selection and sets the flag.
    func activateGlobalSearch() {
        guard !isGlobalSearch else { return }
        previousSelection = sidebarSelection
        isGlobalSearch = true
        refreshItems()
    }

    /// Deactivates global search mode: restores the previous sidebar selection and clears the query.
    /// - Parameter restoreSelection: When `true` (default), restores the sidebar selection
    ///   that was active before global search. Pass `false` when the caller already set a new selection.
    func deactivateGlobalSearch(restoreSelection: Bool = true) {
        guard isGlobalSearch else { return }
        let saved = previousSelection
        isGlobalSearch = false
        previousSelection = nil
        if restoreSelection, let previous = saved {
            sidebarSelection = previous
        }
        searchQuery = ""
    }

    func updateSearchSuggestions(query: String) {
        searchSuggestionTask?.cancel()
        searchSuggestionGeneration += 1
        let generation = searchSuggestionGeneration
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchSuggestions = []
            return
        }
        let requestedContext = navigationContext
        searchSuggestionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await search.execute(query: trimmed, in: .allItems)
                try Task.checkCancellation()
                guard generation == searchSuggestionGeneration,
                      requestedContext == navigationContext else { return }
                searchSuggestions = results.filter {
                    isInNavigationContext($0, context: requestedContext)
                }
            } catch is CancellationError {
                return
            } catch {
                guard generation == searchSuggestionGeneration,
                      requestedContext == navigationContext else { return }
                logger.error("Search suggestions failed: \(error.localizedDescription, privacy: .public)")
                searchSuggestions = []
            }
        }
    }

    func openSearchSuggestion(_ item: VaultItem) {
        selectedItemIDs = [item.id]
        itemSelection = item
        searchSuggestions = []
    }

    /// Copies `value` to the pasteboard and schedules a 30-second auto-clear (FR-011).
    func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        // Cancel any previous clear task before scheduling a new one.
        clipboardClearTask?.cancel()
        clipboardClearTask = Task {
            do {
                try await Task.sleep(for: .seconds(30))
                // Only clear if our value is still on the clipboard.
                if pasteboard.string(forType: .string) == value {
                    pasteboard.clearContents()
                    logger.debug("Clipboard auto-cleared after 30 s")
                }
            } catch {
                // Task cancelled (e.g. new copy) - do nothing.
            }
        }
    }

    /// Dismisses the sync error banner (FR-049).
    func dismissSyncError() {
        syncErrorMessage = nil
    }

    /// Clears all account-bound presentation state before another profile is selected.
    func resetForAccountChange() {
        itemRefreshGeneration += 1
        searchSuggestionGeneration += 1
        searchSuggestionTask?.cancel()
        clipboardClearTask?.cancel()
        NSPasteboard.general.clearContents()

        isGlobalSearch = false
        previousSelection = nil
        navigationContext = .allVaults
        sidebarSelection = .allItems
        searchQuery = ""
        searchSuggestions = []
        itemSelection = nil
        selectedItemIDs = []
        displayedItems = []
        itemCounts = [:]
        folders = []
        organizations = []
        collections = []
        lastSyncedAt = nil
        syncStatusLabel = "Never synced"
        syncErrorMessage = nil
        actionError = nil
        createItemType = nil
        isEditingItem = false
        isLoadingItems = false
    }

    // MARK: - Refresh

    /// Refreshes `displayedItems` from the vault store based on current selection + search query.
    /// Executes the vault read on the actor executor via a fire-and-forget `Task`.
    func refreshItems(showLoadingIndicator: Bool = false) {
        itemRefreshGeneration += 1
        let generation = itemRefreshGeneration
        let requestedQuery = searchQuery
        if showLoadingIndicator {
            isLoadingItems = true
        }

        Task { [weak self] in
            guard let self else { return }
            let requestedContext = navigationContext
            defer {
                if generation == itemRefreshGeneration {
                    isLoadingItems = false
                }
            }
            do {
                let scope: SidebarSelection
                if isGlobalSearch {
                    if case .folder = sidebarSelection { scope = sidebarSelection }
                    else { scope = .allItems }
                } else {
                    scope = sidebarSelection
                }
                let results = try await search.execute(query: requestedQuery, in: scope)
                guard generation == itemRefreshGeneration,
                      requestedContext == navigationContext else { return }
                displayedItems = results.filter { isInNavigationContext($0, context: requestedContext) }
                let visibleSelection = selectedItemIDs.intersection(displayedItems.map(\.id))
                if visibleSelection != selectedItemIDs {
                    updateItemSelection(visibleSelection)
                }
                if !requestedQuery.isEmpty,
                   selectedItemIDs.isEmpty,
                   let firstItem = displayedItems.first {
                    updateItemSelection([firstItem.id])
                }
            } catch {
                guard generation == itemRefreshGeneration,
                      requestedContext == navigationContext else { return }
                logger.error("Failed to load vault items: \(error.localizedDescription, privacy: .public)")
                displayedItems = []
            }
        }
    }

    /// Re-reads the currently selected item from the vault store and updates `itemSelection`.
    ///
    /// Called after a successful attachment upload so the detail pane reflects the new
    /// attachment list without requiring a full vault sync. Safe to call on cancel - if
    /// the item hasn't changed the assignment is a no-op.
    func refreshItemSelection() {
        guard let currentId = itemSelection?.id else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let updated = try? await vault.allItems().first(where: { $0.id == currentId }) else { return }
            itemSelection = updated
        }
    }

    /// Refreshes sidebar item counts from the vault store.
    func refreshCounts() {
        Task { [weak self] in
            guard let self else { return }
            let requestedContext = navigationContext
            do {
                var counts = try await vault.itemCounts()
                guard requestedContext != .allVaults else {
                    guard requestedContext == navigationContext else { return }
                    itemCounts = counts
                    return
                }

                let activeItems = try await vault.items(for: .allItems)
                    .filter { isInNavigationContext($0, context: requestedContext) }
                let deletedItems = try await vault.items(for: .trash)
                    .filter { isInNavigationContext($0, context: requestedContext) }

                counts[.allItems] = activeItems.count
                counts[.favorites] = activeItems.filter(\.isFavorite).count
                counts[.trash] = deletedItems.count

                for type in ItemType.allCases {
                    counts[.type(type)] = activeItems.filter {
                        $0.content.matchesItemType(type)
                    }.count
                }
                for folder in folders {
                    counts[.folder(folder.id)] = activeItems.filter {
                        $0.folderId == folder.id
                    }.count
                }
                for collection in collections {
                    counts[.collection(collection.id)] = activeItems.filter {
                        $0.collectionIds.contains(collection.id)
                    }.count
                }

                guard requestedContext == navigationContext else { return }
                itemCounts = counts
            } catch {
                logger.error("Failed to load item counts: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Re-scopes the sync timestamp repository to a newly resolved account email.
    ///
    /// Called by `RootViewModel` immediately after a login or unlock transition to `.vault`,
    /// before `handleSyncCompleted` - ensures the timestamp is written to and read from
    /// the correct per-account UserDefaults key even on first launch (when the email was
    /// not yet known at `AppContainer.init()` time).
    func updateSyncTimestamp(
        repository: any SyncTimestampRepository,
        useCase:    any GetLastSyncDateUseCase
    ) {
        self.syncTimestamp   = repository
        self.getLastSyncDate = useCase
        // Reload the persisted timestamp from the now-correct account-scoped key.
        lastSyncedAt    = useCase.execute()
        syncStatusLabel = lastSyncedAt.syncStatusLabel()
    }

    /// Called after a successful sync to update counts, items, and timestamp.
    ///
    /// Also persists the timestamp via `SyncTimestampRepository` so it survives app restarts.
    /// Error paths MUST NOT call this method - the stored timestamp reflects the last *successful* sync.
    func handleSyncCompleted(syncedAt: Date) {
        lastSyncedAt = syncedAt
        syncStatusLabel = syncedAt.syncStatusLabel()
        syncTimestamp.recordSuccessfulSync()
        refreshItems()
        refreshCounts()
        refreshFolders()
        refreshOrganizations()
        // Re-read the selected item from the vault store so its attachment list
        // reflects the latest sync data. Without this, itemSelection can be a
        // stale copy (e.g. from before a cipher-key fix that silently dropped
        // attachments), and the detail pane would show "No attachments" even
        // after a sync that correctly mapped them.
        refreshItemSelection()
        syncErrorMessage = nil
    }

    /// Called when a sync fails mid-session (FR-049).
    func handleSyncError(_ message: String) {
        syncErrorMessage = message
    }

    /// Called by `ItemDetailView` when in-place item editing starts or ends.
    func setItemEditing(_ isEditing: Bool) {
        isEditingItem = isEditing
    }

    /// Called after a successful item edit save to refresh the list pane and detail pane.
    ///
    /// Updates `itemSelection` so the detail pane reflects the saved values, then
    /// refreshes the item list and sidebar counts so any name change appears immediately.
    func handleItemSaved(_ updatedItem: VaultItem) {
        itemSelection = updatedItem
        refreshItems()
        refreshCounts()
    }

    func handleTransferFinished(_ transferredItems: [VaultItem]) {
        if transferredItems.count == 1, let transferredItem = transferredItems.first {
            itemSelection = transferredItem
        } else if transferredItems.count > 1 {
            itemSelection = nil
        }
        refreshItems()
        refreshCounts()
    }

    // MARK: - Toggle Favorite

    func toggleFavorite(item: VaultItem) {
        Task {
            var draft = DraftVaultItem(item)
            draft.isFavorite.toggle()
            do {
                let updated = try await vault.update(draft)
                handleItemSaved(updated)
            } catch {
                logger.error("Toggle favorite failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func addToFavorites(items: [VaultItem]) {
        Task {
            var failedNames: [String] = []
            for item in items where !item.isFavorite {
                var draft = DraftVaultItem(item)
                draft.isFavorite = true
                do {
                    _ = try await vault.update(draft)
                } catch {
                    failedNames.append(item.name)
                    logger.error("Bulk favorite failed for \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            refreshItems()
            refreshCounts()
            if !failedNames.isEmpty {
                actionError = "Could not add to Favorites: \(failedNames.joined(separator: ", "))."
            }
        }
    }

    func performSoftDelete(items: [VaultItem]) async {
        var failedNames: [String] = []
        let ids = Set(items.map(\.id))
        for item in items {
            do {
                try await deleteUseCase.execute(id: item.id)
            } catch {
                failedNames.append(item.name)
                logger.error("Bulk delete failed for \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        if itemSelection.map({ ids.contains($0.id) }) == true {
            itemSelection = nil
        }
        refreshItems()
        refreshCounts()
        if !failedNames.isEmpty {
            actionError = "Could not move to Trash: \(failedNames.joined(separator: ", "))."
        }
    }

    // MARK: - Delete / Restore / Empty Trash

    /// Soft-deletes `id`, moving it to Trash.
    ///
    /// On success refreshes the active list and sidebar counts. If the deleted item was
    /// selected in the detail pane, it is deselected so the empty-state appears.
    /// Errors are surfaced via `actionError` for the Presentation layer to show as an alert.
    func performSoftDelete(id: String) async {
        do {
            try await deleteUseCase.execute(id: id)
            logger.info("Item soft-deleted: \(id, privacy: .public)")
            if itemSelection?.id == id {
                let idx = displayedItems.firstIndex(where: { $0.id == id })
                refreshItems()
                if let idx {
                    itemSelection = displayedItems.indices.contains(idx) ? displayedItems[idx]
                        : displayedItems.indices.contains(idx - 1) ? displayedItems[idx - 1]
                        : nil
                } else {
                    itemSelection = nil
                }
            } else {
                refreshItems()
            }
            refreshCounts()
        } catch {
            logger.error("Soft-delete failed for \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }

    /// Restores the trashed item with `id` to the active vault.
    ///
    /// On success refreshes the list and sidebar counts. If the restored item was selected
    /// in the detail pane, deselects it (it has moved to the active vault).
    func performRestore(id: String) async {
        do {
            try await restoreUseCase.execute(id: id)
            logger.info("Item restored: \(id, privacy: .public)")
            if itemSelection?.id == id { itemSelection = nil }
            refreshItems()
            refreshCounts()
        } catch {
            logger.error("Restore failed for \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }

    /// Permanently deletes the trashed item with `id`.
    ///
    /// The item must already be in Trash (`isDeleted == true`). Calls `DELETE /ciphers/{id}`
    /// via `PermanentDeleteVaultItemUseCase`, which permanently removes the cipher from the server.
    /// The caller is responsible for showing a confirmation alert before invoking this method.
    func performPermanentDelete(id: String) async {
        do {
            try await permanentDeleteUseCase.execute(id: id)
            logger.info("Item permanently deleted: \(id, privacy: .public)")
            if itemSelection?.id == id { itemSelection = nil }
            refreshItems()
            refreshCounts()
        } catch {
            logger.error("Permanent delete failed for \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }

    // MARK: - Folder CRUD

    func createFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                _ = try await createFolderUseCase.execute(name: trimmed)
                refreshFolders()
                refreshCounts()
            } catch {
                logger.error("Create folder failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

    func renameFolder(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                _ = try await renameFolderUseCase.execute(id: id, name: trimmed)
                refreshFolders()
            } catch {
                logger.error("Rename folder failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

    func deleteFolder(id: String) {
        Task {
            do {
                let wasSelected = if case .folder(let fid) = sidebarSelection { fid == id } else { false }
                try await deleteFolderUseCase.execute(id: id)
                if wasSelected { sidebarSelection = .allItems }
                refreshFolders()
                refreshItems()
                refreshCounts()
            } catch {
                logger.error("Delete folder failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

    func moveItemsToFolder(itemIds: [String], folderId: String) {
        Task {
            do {
                if itemIds.count == 1, let id = itemIds.first {
                    try await moveItemUseCase.execute(itemId: id, folderId: folderId)
                } else {
                    try await moveItemUseCase.execute(itemIds: itemIds, folderId: folderId)
                }
                refreshItems()
                refreshCounts()
            } catch {
                logger.error("Move to folder failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

    // MARK: - Refresh

    func refreshFolders() {
        Task { [weak self] in
            guard let self else { return }
            do {
                folders = try await vault.folders()
            } catch {
                logger.error("Failed to load folders: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func refreshOrganizations() {
        Task { [weak self] in
            guard let self else { return }
            do {
                organizations = try await vault.organizations()
                collections   = try await vault.collections()
                if case .organization(let selectedId) = navigationContext,
                   !organizations.contains(where: { $0.id == selectedId }) {
                    navigationContext = .allVaults
                } else {
                    refreshItems()
                    refreshCounts()
                }
            } catch {
                logger.error("Failed to load organizations: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func isInNavigationContext(
        _ item: VaultItem,
        context: VaultNavigationContext
    ) -> Bool {
        switch context {
        case .allVaults:
            return true
        case .personal:
            let organizationCollectionIds = Set(collections.map(\.id))
            return item.organizationId == nil
                && item.collectionIds.allSatisfy { !organizationCollectionIds.contains($0) }
        case .organization(let organizationId):
            if item.organizationId == organizationId { return true }
            let collectionIds = Set(
                collections
                    .filter { $0.organizationId == organizationId }
                    .map(\.id)
            )
            return item.collectionIds.contains { collectionIds.contains($0) }
        }
    }

    // MARK: - Collection CRUD

    func createCollection(name: String, organizationId: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                _ = try await createCollectionUseCase.execute(name: trimmed, organizationId: organizationId)
                refreshOrganizations()
                refreshCounts()
            } catch {
                logger.error("Create collection failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

    func renameCollection(id: String, organizationId: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                _ = try await renameCollectionUseCase.execute(collectionId: id, name: trimmed,
                                                               organizationId: organizationId)
                refreshOrganizations()
                refreshCounts()
            } catch {
                logger.error("Rename collection failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

    func deleteCollection(id: String, organizationId: String) {
        Task {
            do {
                let wasSelected = if case .collection(let cid) = sidebarSelection { cid == id } else { false }
                try await deleteCollectionUseCase.execute(collectionId: id, organizationId: organizationId)
                if wasSelected { sidebarSelection = .allItems }
                refreshOrganizations()
                refreshCounts()
            } catch {
                logger.error("Delete collection failed: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
        }
    }

}
