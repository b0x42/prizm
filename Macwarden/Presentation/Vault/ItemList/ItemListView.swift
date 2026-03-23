import SwiftUI

// MARK: - ItemListView

/// Middle-column list of vault items for the currently selected sidebar category (FR-040).
///
/// Items are already pre-sorted by `VaultRepositoryImpl`; this view renders them as-is.
/// An empty state message is shown when the list is empty (FR-042).
/// Each row has a context menu with a "Delete" action that moves the item to Trash.
struct ItemListView: View {

    let items:         [VaultItem]
    @Binding var selection: VaultItem?
    let faviconLoader: FaviconLoader
    /// Called when the user confirms moving an item to Trash from the row context menu.
    /// Nil disables the delete context-menu action (e.g. when trash actions are unavailable).
    var onDelete: ((String) async -> Void)? = nil

    // Tracks which item is pending a soft-delete confirmation alert.
    @State private var itemToDelete:    VaultItem? = nil
    @State private var showDeleteAlert: Bool       = false

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "tray",
                    description: Text("No items in this category.")
                )
                .accessibilityIdentifier(AccessibilityID.ItemList.emptyState)
            } else {
                List(items, id: \.id, selection: $selection) { item in
                    ItemRowView(item: item, faviconLoader: faviconLoader)
                        .tag(item)
                        .accessibilityIdentifier(AccessibilityID.ItemList.row(item.id))
                        .contextMenu {
                            if onDelete != nil {
                                Button("Delete", role: .destructive) {
                                    itemToDelete    = item
                                    showDeleteAlert = true
                                }
                            }
                        }
                }
                // Soft-delete confirmation alert — shown when the user selects "Delete"
                // from a row context menu. The item is only moved to Trash, not permanently
                // deleted; it can be recovered from the Trash view.
                .alert(
                    "Move to Trash?",
                    isPresented: $showDeleteAlert,
                    presenting:  itemToDelete
                ) { item in
                    Button("Move to Trash", role: .destructive) {
                        Task { await onDelete?(item.id) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { item in
                    Text("\"\(item.name)\" will be moved to Trash.")
                }
            }
        }
    }
}
