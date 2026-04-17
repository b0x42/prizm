import SwiftUI

// MARK: - SidebarView

/// Left-column sidebar with sections: Menu Items, Folders, Types, Trash.
///
/// Each row displays a live item count sourced from `VaultBrowserViewModel.itemCounts`.
/// The sidebar is always visible, even when a category is empty.
struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @State private var sidebarSections: [SidebarSection] = [.menu, .types, .folders, .organizations, .trash]
    let itemCounts: [SidebarSelection: Int]
    let folders: [Folder]
    var organizations: [Organization] = []
    var collections: [OrgCollection] = []

    // Folder actions — provided by VaultBrowserViewModel
    var onCreateFolder: ((String) -> Void)?
    var onRenameFolder: ((String, String) -> Void)?  // (id, newName)
    var onDeleteFolder: ((Folder) -> Void)?
    var onDropItems: (([String], String) -> Void)?   // (itemIds, folderId)

    // Collection actions — provided by VaultBrowserViewModel
    var onCreateCollection: ((String, String) -> Void)?  // (name, organizationId)
    var onRenameCollection: ((String, String, String) -> Void)?  // (id, orgId, newName)
    var onDeleteCollection: ((String, String) -> Void)?  // (id, orgId)

    // Inline folder rename/create state
    @State private var renamingFolderId: String?
    @State private var renameText: String = ""
    @FocusState private var isRenameFocused: Bool

    @State private var isCreatingFolder = false
    @State private var newFolderName: String = "New Folder"
    @FocusState private var isNewFolderFocused: Bool

    // Inline collection create state: keyed by orgId
    @State private var creatingCollectionInOrg: String? = nil
    @State private var newCollectionName: String = ""
    @FocusState private var isNewCollectionFocused: Bool

    // Inline collection rename state
    @State private var renamingCollectionId: String?
    @State private var renamingCollectionOrgId: String?
    @State private var collectionRenameText: String = ""
    @FocusState private var isCollectionRenameFocused: Bool

    // Delete collection confirmation
    @State private var collectionToDelete: OrgCollection? = nil
    @State private var showDeleteCollectionAlert = false

    // Tree collapse state (per-session)
    @State private var expandedFolderIds: Set<String> = []
    @State private var expandedOrgIds: Set<String> = []

    private var folderTree: [FolderTreeNode] {
        FolderTreeNode.buildTree(from: folders)
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(sidebarSections, id: \.self) { section in
                // Hide the organizations section when the user has no org memberships.
                if section == .organizations && organizations.isEmpty { EmptyView() }
                else {
                    Section(header: sectionHeader(for: section)) {
                        renderRows(for: section)
                    }
                }
            }
            .onMove { from, to in
                sidebarSections.move(fromOffsets: from, toOffset: to)
            }
        }
        .navigationTitle("Prizm")
        .alert("Delete Collection", isPresented: $showDeleteCollectionAlert,
               presenting: collectionToDelete) { col in
            Button("Delete", role: .destructive) {
                onDeleteCollection?(col.id, col.organizationId)
            }
            Button("Cancel", role: .cancel) {}
        } message: { col in
            Text("\u{201C}\(col.name)\u{201D} will be permanently deleted. Items in this collection will remain in the vault.")
        }
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
        case .trash, .organizations:
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
        case .organizations:
            ForEach(organizations) { org in
                let orgCollections = collections.filter { $0.organizationId == org.id }
                OrgDisclosureRow(
                    org: org,
                    collections: orgCollections,
                    itemCounts: itemCounts,
                    isExpanded: Binding(
                        get: { expandedOrgIds.contains(org.id) },
                        set: { if $0 { expandedOrgIds.insert(org.id) } else { expandedOrgIds.remove(org.id) } }
                    ),
                    creatingCollectionInOrg: $creatingCollectionInOrg,
                    newCollectionName: $newCollectionName,
                    isNewCollectionFocused: $isNewCollectionFocused,
                    renamingCollectionId: $renamingCollectionId,
                    renamingCollectionOrgId: $renamingCollectionOrgId,
                    collectionRenameText: $collectionRenameText,
                    isCollectionRenameFocused: $isCollectionRenameFocused,
                    onCreateCollection: { name in onCreateCollection?(name, org.id) },
                    onRenameCollection: { colId, name in onRenameCollection?(colId, org.id, name) },
                    onDeleteCollection: { col in
                        collectionToDelete = col
                        showDeleteCollectionAlert = true
                    }
                )
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

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isDropTargeted = false

    var body: some View {
        Label(displayName ?? folder.name, systemImage: "folder")
            .font(Typography.sidebarRow)
            .badge(count)
            .tag(SidebarSelection.folder(folder.id))
            .listRowBackground(isDropTargeted ? Color.accentColor.opacity(Opacity.dropTarget(contrast)) : Color.clear)
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
    case menu, folders, types, organizations, trash
    var title: String { self.rawValue.capitalized }
}

// MARK: - OrgDisclosureRow

/// Renders one organization as a DisclosureGroup with its collection rows as children.
/// The header optionally shows a `+` button when the user can manage collections.
private struct OrgDisclosureRow: View {
    let org: Organization
    let collections: [OrgCollection]
    let itemCounts: [SidebarSelection: Int]
    @Binding var isExpanded: Bool

    // Inline collection create state
    @Binding var creatingCollectionInOrg: String?
    @Binding var newCollectionName: String
    @FocusState.Binding var isNewCollectionFocused: Bool

    // Inline collection rename state
    @Binding var renamingCollectionId: String?
    @Binding var renamingCollectionOrgId: String?
    @Binding var collectionRenameText: String
    @FocusState.Binding var isCollectionRenameFocused: Bool

    var onCreateCollection: (String) -> Void
    var onRenameCollection: (String, String) -> Void   // (collectionId, newName)
    var onDeleteCollection: (OrgCollection) -> Void

    private var collectionTree: [CollectionTreeNode] {
        CollectionTreeNode.buildTree(from: collections)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Inline new-collection TextField (matching folder create pattern)
            if creatingCollectionInOrg == org.id {
                TextField("Collection name", text: $newCollectionName, onCommit: {
                    commitCreate()
                })
                .focused($isNewCollectionFocused)
                .tag(SidebarSelection.newCollection(organizationId: org.id))
                .onExitCommand {
                    creatingCollectionInOrg = nil
                    newCollectionName = ""
                }
            }

            ForEach(collectionTree) { node in
                CollectionTreeRow(
                    node: node,
                    org: org,
                    itemCounts: itemCounts,
                    renamingCollectionId: $renamingCollectionId,
                    renamingCollectionOrgId: $renamingCollectionOrgId,
                    collectionRenameText: $collectionRenameText,
                    isCollectionRenameFocused: $isCollectionRenameFocused,
                    onRenameCollection: onRenameCollection,
                    onDeleteCollection: onDeleteCollection
                )
            }

            if collections.isEmpty && creatingCollectionInOrg != org.id {
                Text("No collections")
                    .font(Typography.listSubtitle)
                    .foregroundStyle(.secondary)
                    .tag(SidebarSelection?.none)
            }
        } label: {
            orgHeader
        }
        .tag(SidebarSelection.organization(org.id))
    }

    @ViewBuilder
    private var orgHeader: some View {
        if org.canManageCollections {
            HStack(alignment: .firstTextBaseline) {
                Label(org.name, systemImage: "building.2")
                    .font(Typography.sidebarRow)
                    .badge(itemCounts[.organization(org.id)] ?? 0)
                Spacer()
                Button {
                    newCollectionName = ""
                    creatingCollectionInOrg = org.id
                    isExpanded = true
                    isNewCollectionFocused = true
                } label: {
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                }
                .buttonStyle(.plain)
                .help("New Collection")
                .padding(.trailing, 10)
            }
        } else {
            Label(org.name, systemImage: "building.2")
                .font(Typography.sidebarRow)
                .badge(itemCounts[.organization(org.id)] ?? 0)
        }
    }

    private func commitCreate() {
        let trimmed = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        creatingCollectionInOrg = nil
        newCollectionName = ""
        guard !trimmed.isEmpty else { return }
        onCreateCollection(trimmed)
    }
}

// MARK: - CollectionTreeRow

/// Recursive tree row for collections: renders a DisclosureGroup for nodes with children,
/// or a plain collection row for leaf nodes. Mirrors `FolderTreeRow`.
private struct CollectionTreeRow: View {
    let node: CollectionTreeNode
    let org: Organization
    let itemCounts: [SidebarSelection: Int]
    @Binding var renamingCollectionId: String?
    @Binding var renamingCollectionOrgId: String?
    @Binding var collectionRenameText: String
    @FocusState.Binding var isCollectionRenameFocused: Bool
    var onRenameCollection: (String, String) -> Void   // (collectionId, newName)
    var onDeleteCollection: (OrgCollection) -> Void

    @State private var isExpanded = false

    var body: some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children) { child in
                    CollectionTreeRow(
                        node: child,
                        org: org,
                        itemCounts: itemCounts,
                        renamingCollectionId: $renamingCollectionId,
                        renamingCollectionOrgId: $renamingCollectionOrgId,
                        collectionRenameText: $collectionRenameText,
                        isCollectionRenameFocused: $isCollectionRenameFocused,
                        onRenameCollection: onRenameCollection,
                        onDeleteCollection: onDeleteCollection
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
        if let col = node.collection,
           renamingCollectionId == col.id && renamingCollectionOrgId == col.organizationId {
            TextField("Collection name", text: $collectionRenameText, onCommit: {
                let trimmed = collectionRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
                renamingCollectionId    = nil
                renamingCollectionOrgId = nil
                isCollectionRenameFocused = false
                guard !trimmed.isEmpty, trimmed != col.name else { return }
                onRenameCollection(col.id, trimmed)
            })
            .focused($isCollectionRenameFocused)
            .tag(SidebarSelection.collection(col.id))
            .onExitCommand {
                renamingCollectionId    = nil
                renamingCollectionOrgId = nil
                isCollectionRenameFocused = false
            }
        } else if let col = node.collection {
            Label(node.name, systemImage: "tray.2")
                .font(Typography.sidebarRow)
                .badge(itemCounts[.collection(col.id)] ?? 0)
                .tag(SidebarSelection.collection(col.id))
                .contextMenu {
                    if org.canManageCollections {
                        Button("Rename") {
                            collectionRenameText    = col.name
                            renamingCollectionId    = col.id
                            renamingCollectionOrgId = col.organizationId
                            isCollectionRenameFocused = true
                        }
                        Divider()
                        Button("Delete Collection", role: .destructive) {
                            onDeleteCollection(col)
                        }
                    }
                }
        } else {
            // Virtual parent node — not selectable, no context menu
            Label(node.name, systemImage: "tray.2")
                .foregroundStyle(.secondary)
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
            .font(Typography.sidebarRow)
            .badge(count)
            .tag(selection)
    }
}
