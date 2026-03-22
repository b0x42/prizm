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

    @Published private(set) var displayedItems: [VaultItem] = []
    @Published private(set) var itemCounts: [SidebarSelection: Int] = [:]
    @Published private(set) var lastSyncedAt: Date?
    @Published var syncErrorMessage: String? = nil
    /// Reflects whether the edit sheet is currently open. Used by `MenuBarViewModel`
    /// to enable/disable the Edit and Save menu bar actions.
    @Published private(set) var editSheetOpen: Bool = false

    // MARK: - Dependencies

    private let vault:  any VaultRepository
    private let search: any SearchVaultUseCase
    private let logger = Logger(subsystem: "com.macwarden", category: "VaultBrowserViewModel")

    // MARK: - Menu bar action relay

    /// Fired when the "Item > Edit" menu bar action is triggered (spec §9.3).
    /// `ItemDetailView` observes this to open the edit sheet for the selected item.
    let openEditSubject = PassthroughSubject<Void, Never>()

    /// Fired when the "Item > Save" menu bar action is triggered (spec §9.4).
    /// `ItemDetailView` observes this to call `save()` on the active edit ViewModel.
    let saveSubject = PassthroughSubject<Void, Never>()

    // MARK: - Clipboard auto-clear

    private var clipboardClearTask: Task<Void, Never>?

    // MARK: - Init

    init(vault: any VaultRepository, search: any SearchVaultUseCase) {
        self.vault  = vault
        self.search = search
        refreshItems()
        refreshCounts()
        lastSyncedAt = vault.lastSyncedAt
    }

    // MARK: - Actions

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
            displayedItems = try search.execute(query: searchQuery, in: sidebarSelection)
        } catch {
            logger.error("Failed to load vault items: \(error.localizedDescription, privacy: .public)")
            displayedItems = []
        }
    }

    /// Refreshes sidebar item counts from the vault store.
    func refreshCounts() {
        do {
            itemCounts = try vault.itemCounts()
        } catch {
            logger.error("Failed to load item counts: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Called after a successful sync to update counts, items, and timestamp.
    func handleSyncCompleted(syncedAt: Date) {
        lastSyncedAt = syncedAt
        refreshItems()
        refreshCounts()
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
}
