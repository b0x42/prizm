import SwiftUI

// MARK: - SidebarView

/// Left-column sidebar with sections: Menu Items, Folders, Types, Trash.
///
/// Each row displays a live item count sourced from `VaultBrowserViewModel.itemCounts`.
/// The sidebar is always visible, even when a category is empty.
struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @State private var sidebarSections: [SidebarSection] = [.menu, .types, .folders, .trash]
    let itemCounts: [SidebarSelection: Int]
    let folders: [Folder]

    // Folder actions — provided by VaultBrowserViewModel
    var onCreateFolder: ((String) -> Void)?
    var onRenameFolder: ((String, String) -> Void)?  // (id, newName)
    var onDeleteFolder: ((Folder) -> Void)?
    var onDropItems: (([String], String) -> Void)?   // (itemIds, folderId)

    // Inline rename state
    @State private var renamingFolderId: String?
    @State private var renameText: String = ""

    // Inline create state
    @State private var isCreatingFolder = false
    @State private var newFolderName: String = "New Folder"

    var body: some View {
        List(selection: $selection) {
            ForEach(sidebarSections, id: \.self) { section in
                Section(header: sectionHeader(for: section)) {
                    renderRows(for: section)
                }
            }
            .onMove { from, to in
                sidebarSections.move(fromOffsets: from, toOffset: to)
            }
        }
        .navigationTitle("Prizm")
    }

    // MARK: - Section Headers

    @ViewBuilder
    private func sectionHeader(for section: SidebarSection) -> some View {
        switch section {
        case .folders:
            HStack {
                Text(section.title)
                Spacer()
                Button {
                    newFolderName = "New Folder"
                    isCreatingFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                    .font(.title3)
                }
                .buttonStyle(.plain)
                .help("New Folder")
            }
        case .trash:
            EmptyView()
        default:
            Text(section.title)
        }
    }

    // MARK: - Row Rendering

    @ViewBuilder
    private func renderRows(for section: SidebarSection) -> some View {
        switch section {
        case .menu:
            SidebarRowView(title: "All Items", systemImage: "square.grid.2x2", selection: .allItems, count: itemCounts[.allItems] ?? 0)
            SidebarRowView(title: "Favorites", systemImage: "star", selection: .favorites, count: itemCounts[.favorites] ?? 0)
        case .folders:
            if isCreatingFolder {
                TextField("Folder name", text: $newFolderName, onCommit: {
                    commitCreate()
                })
                .onExitCommand {
                    isCreatingFolder = false
                }
            }
            ForEach(folders) { folder in
                folderRow(folder)
            }
            if folders.isEmpty && !isCreatingFolder {
                Text("No folders")
                    .font(Typography.listSubtitle)
                    .foregroundStyle(.secondary)
                    .tag(SidebarSelection?.none)
            }
        case .types:
            ForEach(ItemType.allCases, id: \.self) { type in
                SidebarRowView(title: type.displayName, systemImage: type.sfSymbol, selection: .type(type), count: itemCounts[.type(type)] ?? 0)
            }
        case .trash:
            SidebarRowView(title: "Trash", systemImage: "trash", selection: .trash, count: itemCounts[.trash] ?? 0)
        }
    }

    // MARK: - Folder Row

    @ViewBuilder
    private func folderRow(_ folder: Folder) -> some View {
        if renamingFolderId == folder.id {
            TextField("Folder name", text: $renameText, onCommit: {
                commitRename(folder)
            })
            .onExitCommand {
                renamingFolderId = nil
            }
            .tag(SidebarSelection.folder(folder.id))
        } else {
            Label(folder.name, systemImage: "folder")
                .badge(itemCounts[.folder(folder.id)] ?? 0)
                .tag(SidebarSelection.folder(folder.id))
                .contextMenu {
                    Button("Rename") {
                        renameText = folder.name
                        renamingFolderId = folder.id
                    }
                    Divider()
                    Button("Delete Folder", role: .destructive) {
                        onDeleteFolder?(folder)
                    }
                }
                .dropDestination(for: String.self) { itemIds, _ in
                    guard !itemIds.isEmpty else { return false }
                    onDropItems?(itemIds, folder.id)
                    return true
                }
        }
    }

    private func commitRename(_ folder: Folder) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renamingFolderId = nil
        guard !trimmed.isEmpty, trimmed != folder.name else { return }
        onRenameFolder?(folder.id, trimmed)
    }

    private func commitCreate() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreatingFolder = false
        guard !trimmed.isEmpty else { return }
        onCreateFolder?(trimmed)
    }
}

// MARK: - SidebarSection

enum SidebarSection: String, CaseIterable {
    case menu, folders, types, trash
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
