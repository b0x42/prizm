import SwiftUI

// MARK: - ItemListView

/// Middle-column list of vault items for the currently selected sidebar category (FR-040).
///
/// Items are already pre-sorted by `VaultRepositoryImpl`; this view renders them as-is.
/// An empty state message is shown when the list is empty (FR-042).
struct ItemListView: View {

    let items:         [VaultItem]
    @Binding var selection: VaultItem?
    let faviconLoader: FaviconLoader

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
                }
            }
        }
    }
}
