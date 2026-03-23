import SwiftUI

// MARK: - TrashView

/// Middle-column list of trashed vault items (items where `isDeleted == true`).
///
/// Provides:
/// - Empty state when no items are in trash.
/// - Per-row context menus with "Restore" and "Delete Permanently" actions.
/// - "Empty Trash" toolbar button (disabled when the list is empty).
/// - Confirmation alerts before any destructive operation.
struct TrashView: View {

    let items:         [VaultItem]
    @Binding var selection: VaultItem?
    let faviconLoader: FaviconLoader
    let onRestore:          (String) async -> Void
    /// Called to permanently delete a single trashed item (irreversible).
    let onPermanentDelete:  (String) async -> Void
    let onEmptyTrash:       () async -> Void

    // Confirmation alert state for single-item permanent delete.
    @State private var itemToDelete:    VaultItem? = nil
    @State private var showDeleteAlert: Bool       = false

    // Confirmation alert state for empty-trash.
    @State private var showEmptyTrashAlert: Bool = false

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                List(items, id: \.id, selection: $selection) { item in
                    ItemRowView(item: item, faviconLoader: faviconLoader)
                        .tag(item)
                        .accessibilityIdentifier(AccessibilityID.ItemList.row(item.id))
                        .contextMenu {
                            Button("Restore") {
                                Task { await onRestore(item.id) }
                            }
                            Divider()
                            Button("Delete Permanently", role: .destructive) {
                                itemToDelete    = item
                                showDeleteAlert = true
                            }
                            .accessibilityIdentifier(AccessibilityID.Trash.permanentDeleteButton)
                        }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Empty Trash") {
                    showEmptyTrashAlert = true
                }
                .disabled(items.isEmpty)
                .accessibilityIdentifier(AccessibilityID.Trash.emptyTrashButton)
            }
        }
        // Confirmation alert: single permanent delete.
        .alert(
            "Delete Permanently?",
            isPresented: $showDeleteAlert,
            presenting:  itemToDelete
        ) { item in
            Button("Delete Permanently", role: .destructive) {
                Task { await onPermanentDelete(item.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("\"\(item.name)\" will be permanently deleted and cannot be recovered.")
        }
        // Confirmation alert: empty trash.
        .alert("Empty Trash?", isPresented: $showEmptyTrashAlert) {
            Button("Empty Trash", role: .destructive) {
                Task { await onEmptyTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(items.count) item\(items.count == 1 ? "" : "s") in Trash will be permanently deleted and cannot be recovered.")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No Items in Trash",
            systemImage: "trash",
            description: Text("Items you delete will appear here.")
        )
        .accessibilityIdentifier(AccessibilityID.Trash.emptyState)
    }
}
