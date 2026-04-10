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
    @FocusState private var isRenameFocused: Bool

    // Inline create state
    @State private var isCreatingFolder = false
    @State private var newFolderName: String = "New Folder"
    @FocusState private var isNewFolderFocused: Bool

    // Tree collapse state (per-session)
    @State private var expandedFolderIds: Set<String> = []

    private var folderTree: [FolderTreeNode] {
        FolderTreeNode.buildTree(from: folders)
    }

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
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                Spacer()
                Button {
                    newFolderName = "New Folder"
                    isCreatingFolder = true
                    selection = .newFolder
                    isNewFolderFocused = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                }
                .buttonStyle(.plain)
                .help("New Folder")
                .accessibilityLabel("New Folder")
                .padding(.trailing, 10)
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
                TextField("Name or Parent/Name", text: $newFolderName, onCommit: {
                    commitCreate()
                })
                .focused($isNewFolderFocused)
                .tag(SidebarSelection.newFolder)
                .help("Nest a folder by adding the parent folder's name followed by a /. Example: Social/Forums")
                .onExitCommand {
                    isCreatingFolder = false
                    selection = nil
                }
            }
            ForEach(folderTree) { node in
                FolderTreeRow(
                    node: node,
                    itemCounts: itemCounts,
                    expandedIds: $expandedFolderIds,
                    renamingFolderId: $renamingFolderId,
                    renameText: $renameText,
                    isRenameFocused: $isRenameFocused,
                    onDeleteFolder: { onDeleteFolder?($0) },
                    onDropItems: { ids, fid in onDropItems?(ids, fid) },
                    onRenameFolder: { id, name in onRenameFolder?(id, name) }
                )
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

    private func commitCreate() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreatingFolder = false
        selection = nil
        guard !trimmed.isEmpty else { return }
        onCreateFolder?(trimmed)
    }
}

// MARK: - FolderTreeRow

/// Recursive tree row: renders a DisclosureGroup for nodes with children,
/// or a plain folder row for leaf nodes.
private struct FolderTreeRow: View {
    let node: FolderTreeNode
    let itemCounts: [SidebarSelection: Int]
    @Binding var expandedIds: Set<String>
    @Binding var renamingFolderId: String?
    @Binding var renameText: String
    @FocusState.Binding var isRenameFocused: Bool
    var onDeleteFolder: (Folder) -> Void
    var onDropItems: ([String], String) -> Void
    var onRenameFolder: ((String, String) -> Void)?

    var body: some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: Binding(
                get: { expandedIds.contains(node.id) },
                set: { expanded in
                    if expanded { expandedIds.insert(node.id) }
                    else { expandedIds.remove(node.id) }
                }
            )) {
                ForEach(node.children) { child in
                    FolderTreeRow(
                        node: child,
                        itemCounts: itemCounts,
                        expandedIds: $expandedIds,
                        renamingFolderId: $renamingFolderId,
                        renameText: $renameText,
                        isRenameFocused: $isRenameFocused,
                        onDeleteFolder: onDeleteFolder,
                        onDropItems: onDropItems,
                        onRenameFolder: onRenameFolder
                    )
                }
            } label: {
                nodeLabel
            }
        } else {
            nodeLabel
        }
    }

    @ViewBuilder
    private var nodeLabel: some View {
        if let folder = node.folder, renamingFolderId == folder.id {
            TextField("Name or Parent/Name", text: $renameText, onCommit: {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                renamingFolderId = nil
                isRenameFocused = false
                guard !trimmed.isEmpty else { return }
                let parts = folder.name.split(separator: "/").map(String.init)
                let newName = parts.count > 1
                    ? parts.dropLast().joined(separator: "/") + "/" + trimmed
                    : trimmed
                guard newName != folder.name else { return }
                onRenameFolder?(folder.id, newName)
            })
            .focused($isRenameFocused)
            .tag(SidebarSelection.folder(folder.id))
            .help("Nest a folder by adding the parent folder's name followed by a /. Example: Social/Forums")
            .onExitCommand {
                renamingFolderId = nil
                isRenameFocused = false
            }
        } else if let folder = node.folder {
            // Real folder — selectable, droppable
            FolderRowLabel(
                folder: folder,
                displayName: node.name,
                count: itemCounts[.folder(folder.id)] ?? 0,
                onRename: {
                    renameText = node.name
                    renamingFolderId = folder.id
                    isRenameFocused = true
                },
                onDelete: { onDeleteFolder(folder) },
                onDrop: { ids in onDropItems(ids, folder.id) }
            )
        } else {
            // Virtual parent — not selectable, no drop, no context menu
            Label(node.name, systemImage: "folder")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - FolderRowLabel

/// Folder row with drop-target highlight and context menu.
/// Extracted to a struct so `@State var isDropTargeted` is per-row.
private struct FolderRowLabel: View {
    let folder: Folder
    var displayName: String? = nil
    let count: Int
    var onRename: () -> Void
    var onDelete: () -> Void
    var onDrop: ([String]) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        Label(displayName ?? folder.name, systemImage: "folder")
            .font(Typography.sidebarRow)
            .badge(count)
            .tag(SidebarSelection.folder(folder.id))
            .listRowBackground(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
            .contextMenu {
                Button("Rename") { onRename() }
                Divider()
                Button("Delete Folder", role: .destructive) { onDelete() }
            }
            .dropDestination(for: String.self) { itemIds, _ in
                guard !itemIds.isEmpty else { return false }
                onDrop(itemIds)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
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
            .font(Typography.sidebarRow)
            .badge(count)
            .tag(selection)
    }
}
