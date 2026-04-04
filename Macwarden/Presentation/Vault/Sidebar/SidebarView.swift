import SwiftUI

// MARK: - SidebarView

/// Left-column sidebar with two named sections: *Menu Items* and *Types* (FR-006).
///
/// Each row displays a live item count sourced from `VaultBrowserViewModel.itemCounts`.
/// The sidebar is always visible, even when a category is empty (FR-006, FR-042).
/// A persistent footer (`SidebarFooterView`) is pinned below the list via
/// `.safeAreaInset(edge: .bottom)` so it stays visible regardless of scroll position.
struct SidebarView: View {

    @Binding var selection: SidebarSelection?
    let itemCounts:  [SidebarSelection: Int]
    let account:     Account
    let syncService: any SyncStatusProviding

    var body: some View {
        List(selection: $selection) {
            // MARK: Menu Items section
            Section("Menu Items") {
                SidebarRowView(
                    title:      "All Items",
                    systemImage: "square.grid.2x2",
                    selection:  .allItems,
                    count:      itemCounts[.allItems] ?? 0
                )
                .accessibilityIdentifier(AccessibilityID.Sidebar.allItems)
                SidebarRowView(
                    title:      "Favorites",
                    systemImage: "star",
                    selection:  .favorites,
                    count:      itemCounts[.favorites] ?? 0
                )
                .accessibilityIdentifier(AccessibilityID.Sidebar.favorites)
            }

            // MARK: Types section
            Section("Types") {
                ForEach(ItemType.allCases, id: \.self) { type in
                    SidebarRowView(
                        title:      type.displayName,
                        systemImage: type.sfSymbol,
                        selection:  .type(type),
                        count:      itemCounts[.type(type)] ?? 0
                    )
                    .accessibilityIdentifier(AccessibilityID.Sidebar.type(type.displayName))
                }
            }

            // MARK: Trash section
            // Shown without a badge count when empty so users know the section exists.
            Section {
                SidebarRowView(
                    title:       "Trash",
                    systemImage: "trash",
                    selection:   .trash,
                    count:       itemCounts[.trash] ?? 0
                )
                .accessibilityIdentifier(AccessibilityID.Sidebar.trash)
            }
        }
        .navigationTitle("Macwarden")
        // Pin the footer below the scrollable list so it stays visible at all times
        // without disturbing the List's insets or safe area.
        .safeAreaInset(edge: .bottom) {
            SidebarFooterView(
                vaultName:   account.name ?? account.email,
                syncService: syncService
            )
        }
    }
}

// MARK: - SidebarRowView

private struct SidebarRowView: View {
    let title:       String
    let systemImage: String
    let selection:   SidebarSelection
    let count:       Int

    var body: some View {
        Label(title, systemImage: systemImage)
            .badge(count)
            .tag(selection)
    }
}
