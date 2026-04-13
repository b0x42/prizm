import AppKit
import Combine
import Foundation
import os.log

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
                Task { @MainActor [weak self] in
                    self?.itemSelection = nil
                    self?.refreshItems()
                }
            }
        }
    }

    @Published var itemSelection: VaultItem?
    @Published var searchQuery:   String = "" {
        didSet { Task { @MainActor in refreshItems() } }
    }

    /// When true, search queries are scoped to `.allItems` regardless of sidebar selection.
    @Published private(set) var isGlobalSearch: Bool = false

    /// The sidebar selection that was active before global search was activated.
    private(set) var previousSelection: SidebarSelection?

    @Published private(set) var displayedItems: [VaultItem] = []
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
    /// Reflects whether the edit sheet is currently open. Used by `MenuBarViewModel`
    /// to enable/disable the Edit and Save menu bar actions.
    @Published private(set) var editSheetOpen: Bool = false

    // MARK: - Published state (trash actions)

    /// Set when a delete, restore, or empty-trash operation fails.
    /// The Presentation layer surfaces this as an alert.
    @Published var actionError: String? = nil

    /// Set to a non-nil `ItemType` to present the create sheet for that type.
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
    func triggerSave() { saveTrigger += 1 }

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
        // Load persisted timestamp first; fall back to in-memory value from the vault store
        // (populated on the current session's sync, but not persisted across restarts).
        lastSyncedAt   = getLastSyncDate.execute() ?? vault.lastSyncedAt
        syncStatusLabel = lastSyncedAt.syncStatusLabel()
        startLabelRefreshTimer()
    }

    deinit {
        labelRefreshTimer?.invalidate()
        clipboardClearTask?.cancel()
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
                // Task cancelled (e.g. new copy) — do nothing.
            }
        }
    }

    /// Dismisses the sync error banner (FR-049).
    func dismissSyncError() {
        syncErrorMessage = nil
    }

    // MARK: - Refresh

    /// Refreshes `displayedItems` from the vault store based on current selection + search query.
    func refreshItems() {
        do {
            let scope: SidebarSelection
            if isGlobalSearch {
                if case .folder = sidebarSelection { scope = sidebarSelection }
                else { scope = .allItems }
            } else {
                scope = sidebarSelection
            }
            displayedItems = try search.execute(query: searchQuery, in: scope)
        } catch {
            logger.error("Failed to load vault items: \(error.localizedDescription, privacy: .public)")
            displayedItems = []
        }
    }

    /// Re-reads the currently selected item from the vault store and updates `itemSelection`.
    ///
    /// Called after a successful attachment upload so the detail pane reflects the new
    /// attachment list without requiring a full vault sync. Safe to call on cancel — if
    /// the item hasn't changed the assignment is a no-op.
    func refreshItemSelection() {
        guard let currentId = itemSelection?.id else { return }
        guard let updated = try? vault.allItems().first(where: { $0.id == currentId }) else { return }
        itemSelection = updated
    }

    /// Refreshes sidebar item counts from the vault store.
    func refreshCounts() {
        do {
            itemCounts = try vault.itemCounts()
        } catch {
            logger.error("Failed to load item counts: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Re-scopes the sync timestamp repository to a newly resolved account email.
    ///
    /// Called by `RootViewModel` immediately after a login or unlock transition to `.vault`,
    /// before `handleSyncCompleted` — ensures the timestamp is written to and read from
    /// the correct per-account UserDefaults key even on first launch (when the email was
    /// not yet known at `AppContainer.init()` time).
    func updateSyncTimestamp(
        repository: any SyncTimestampRepository,
        useCase:    any GetLastSyncDateUseCase
    ) {
        self.syncTimestamp   = repository
        self.getLastSyncDate = useCase
        // Reload the persisted timestamp from the now-correct account-scoped key.
        lastSyncedAt    = useCase.execute() ?? vault.lastSyncedAt
        syncStatusLabel = lastSyncedAt.syncStatusLabel()
    }

    /// Called after a successful sync to update counts, items, and timestamp.
    ///
    /// Also persists the timestamp via `SyncTimestampRepository` so it survives app restarts.
    /// Error paths MUST NOT call this method — the stored timestamp reflects the last *successful* sync.
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

    /// Called by `ItemDetailView` when the edit sheet opens or closes.
    func handleEditSheetState(_ open: Bool) {
        editSheetOpen = open
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
        do {
            folders = try vault.folders()
        } catch {
            logger.error("Failed to load folders: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshOrganizations() {
        do {
            organizations = try vault.organizations()
            collections   = try vault.collections()
        } catch {
            logger.error("Failed to load organizations: \(error.localizedDescription, privacy: .public)")
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
