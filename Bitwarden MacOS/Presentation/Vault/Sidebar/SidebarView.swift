import SwiftUI

// MARK: - SidebarView

/// Left-column sidebar with two named sections: *Menu Items* and *Types* (FR-006).
///
/// Each row displays a live item count sourced from `VaultBrowserViewModel.itemCounts`.
/// The sidebar is always visible, even when a category is empty (FR-006, FR-042).
struct SidebarView: View {

    @Binding var selection: SidebarSelection
    let itemCounts: [SidebarSelection: Int]

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
                        systemImage: sfSymbol(for: type),
                        selection:  .type(type),
                        count:      itemCounts[.type(type)] ?? 0
                    )
                    .accessibilityIdentifier(AccessibilityID.Sidebar.type(type.displayName))
                }
            }
        }
        .navigationTitle("Bitwarden")
    }

    // MARK: - Private helpers

    private func sfSymbol(for type: ItemType) -> String {
        switch type {
        case .login:      return "key"
        case .card:       return "creditcard"
        case .identity:   return "person.crop.rectangle"
        case .secureNote: return "note.text"
        case .sshKey:     return "terminal"
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
