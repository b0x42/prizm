import SwiftUI

// MARK: - SidebarView

/// Left-column sidebar with two named sections: *Menu Items* and *Types* (FR-006).
///
/// Each row displays a live item count sourced from `VaultBrowserViewModel.itemCounts`.
/// The sidebar is always visible, even when a category is empty (FR-006, FR-042).
struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @State private var sidebarSections: [SidebarSection] = [.menu, .types, .trash]
    let itemCounts: [SidebarSelection: Int]

    var body: some View {
        List(selection: $selection) {
            ForEach(sidebarSections, id: \.self) { section in
                // Check if the section is NOT trash to show the header
                Section(header: section == .trash ? nil : Text(section.title)) {
                    renderRows(for: section)
                }
            }
            .onMove { from, to in
                sidebarSections.move(fromOffsets: from, toOffset: to)
            }
        }
        .navigationTitle("Prizm")
    }

    // Helper to render the specific rows for each section type
    @ViewBuilder
    private func renderRows(for section: SidebarSection) -> some View {
        switch section {
        case .menu:
            SidebarRowView(title: "All Items", systemImage: "square.grid.2x2", selection: .allItems, count: itemCounts[.allItems] ?? 0)
            SidebarRowView(title: "Favorites", systemImage: "star", selection: .favorites, count: itemCounts[.favorites] ?? 0)
        case .types:
            ForEach(ItemType.allCases, id: \.self) { type in
                SidebarRowView(title: type.displayName, systemImage: type.sfSymbol, selection: .type(type), count: itemCounts[.type(type)] ?? 0)
            }
        case .trash:
            SidebarRowView(title: "Trash", systemImage: "trash", selection: .trash, count: itemCounts[.trash] ?? 0)
        }
    }
}

enum SidebarSection: String, CaseIterable {
    case menu, types, trash
    var title: String { self.rawValue.capitalized }
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
