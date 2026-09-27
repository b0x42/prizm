import SwiftUI

// MARK: - SidebarView

/// Left-column sidebar with sections: Menu Items, Folders, Types, Trash.
///
/// Each row displays a live item count sourced from `VaultBrowserViewModel.itemCounts`.
/// The sidebar is always visible, even when a category is empty.
struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @Binding var navigationContext: VaultNavigationContext
    @State private var sidebarSections: [SidebarSection] = [.menu, .types, .folders, .organizations, .trash]
    let organizationExplorerLayout: OrganizationExplorerLayout
    let itemCounts: [SidebarSelection: Int]
    let folders: [Folder]
    var organizations: [Organization] = []
    var collections: [OrgCollection] = []

    // Folder actions - provided by VaultBrowserViewModel
    var onCreateFolder: ((String) -> Void)?
    var onRenameFolder: ((String, String) -> Void)?  // (id, newName)
    var onDeleteFolder: ((Folder) -> Void)?
    var onDropItems: (([String], String) -> Void)?   // (itemIds, folderId)

    // Collection actions - provided by VaultBrowserViewModel
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
    @State private var isContextPickerPresented = false

    private var folderTree: [FolderTreeNode] {
        FolderTreeNode.buildTree(from: folders)
    }

    private var selectedOrganization: Organization? {
        guard case .organization(let id) = navigationContext else { return nil }
        return organizations.first { $0.id == id }
    }

    private var selectedOrganizationCollections: [OrgCollection] {
        guard let selectedOrganization else { return [] }
        return collections.filter { $0.organizationId == selectedOrganization.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if organizationExplorerLayout == .dropdown {
                contextPicker
                Divider()
                    .overlay(DesignColor.paneDivider)
                Color.clear
                    .frame(height: Spacing.cardTop)
                    .accessibilityHidden(true)
            }

            List(selection: $selection) {
                ForEach(sidebarSections, id: \.self) { section in
                    if shouldShow(section) {
                        Section(header: sectionHeader(for: section)) {
                            renderRows(for: section)
                        }
                    }
                }
                .onMove { from, to in
                    sidebarSections.move(fromOffsets: from, toOffset: to)
                }
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

    private var contextPicker: some View {
        VStack(spacing: 0) {
            Button {
                isContextPickerPresented.toggle()
            } label: {
                HStack(spacing: Spacing.headerGap) {
                    Image(systemName: navigationContextIcon)
                        .font(Typography.contextDropdownIcon)
                        .foregroundStyle(DesignColor.selectedContentForeground)
                        .padding(Spacing.contextPickerIconPadding)
                        .background(
                            Color.accentColor.gradient,
                            in: RoundedRectangle(cornerRadius: Spacing.badgeCornerRadius)
                        )
                        .accessibilityHidden(true)

                    Text(navigationContextName)
                        .font(Typography.contextDropdownLabel)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: Spacing.headerGap)

                    Image(systemName: "chevron.down")
                        .font(Typography.utility)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.contextPickerHorizontal)
                .padding(.vertical, Spacing.rowVertical)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)
            .accessibilityLabel("Vault Context")
            .accessibilityValue(navigationContextName)
            .popover(isPresented: $isContextPickerPresented, arrowEdge: .bottom) {
                SearchableSelectPopover(
                    title: "vaults",
                    selection: $navigationContext,
                    options: contextOptions
                ) {
                    isContextPickerPresented = false
                }
            }
        }
        .padding(.horizontal, Spacing.contextPickerOuterHorizontal)
        .padding(.top, Spacing.sidebarContextTop)
        .padding(.bottom, Spacing.sidebarContextBottom)
    }

    private var contextOptions: [SearchableSelectOption<VaultNavigationContext>] {
        [
            SearchableSelectOption(
                value: .allVaults,
                title: "All Vaults",
                systemImage: "square.stack.3d.up"
            ),
            SearchableSelectOption(
                value: .personal,
                title: "My Vault",
                systemImage: "person.crop.circle"
            )
        ] + organizations.map { organization in
            SearchableSelectOption(
                value: .organization(organization.id),
                title: organization.name,
                systemImage: "building.2"
            )
        }
    }

    private var navigationContextIcon: String {
        switch navigationContext {
        case .allVaults:
            "square.stack.3d.up"
        case .personal:
            "person.crop.circle"
        case .organization:
            "building.2"
        }
    }

    private var navigationContextName: String {
        switch navigationContext {
        case .allVaults:
            "All Vaults"
        case .personal:
            "My Vault"
        case .organization(let id):
            organizations.first(where: { $0.id == id })?.name ?? "Organization"
        }
    }

    private func shouldShow(_ section: SidebarSection) -> Bool {
        guard organizationExplorerLayout == .dropdown else {
            return section != .organizations || !organizations.isEmpty
        }

        switch (section, navigationContext) {
        case (.folders, .organization):
            return false
        case (.organizations, .personal):
            return false
        case (.organizations, _):
            return !organizations.isEmpty
        default:
            return true
        }
    }

    // MARK: - Section Headers

    @ViewBuilder
    private func sectionHeader(for section: SidebarSection) -> some View {
        switch section {
        case .menu:
            EmptyView()
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
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .offset(y: -4)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                }
                .buttonStyle(.plain)
                .help("New Folder")
                .accessibilityLabel("New Folder")
                .padding(.trailing, 14)
            }
        case .trash:
            EmptyView()
        case .organizations:
            if organizationExplorerLayout == .dropdown,
               let organization = selectedOrganization {
                HStack(alignment: .firstTextBaseline) {
                    Text("Collections")
                    Spacer()
                    if organization.canManageCollections {
                        Button {
                            newCollectionName = ""
                            creatingCollectionInOrg = organization.id
                            isNewCollectionFocused = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(Typography.sectionHeader)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .help("New Collection")
                        .accessibilityLabel("New Collection")
                        .padding(.trailing, Spacing.rowHorizontal)
                    }
                }
            } else {
                Text(section.title)
            }
        default:
            Text(section.title)
        }
    }

    // MARK: - Row Rendering

    @ViewBuilder
    private func renderRows(for section: SidebarSection) -> some View {
        switch section {
        case .menu:
            SidebarRowView(title: "All Items", systemImage: "square.grid.2x2", selection: .allItems, currentSelection: selection, count: itemCounts[.allItems] ?? 0)
            SidebarRowView(title: "Favorites", systemImage: "star", selection: .favorites, currentSelection: selection, count: itemCounts[.favorites] ?? 0)
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
                    currentSelection: selection,
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
                SidebarRowView(title: type.displayName, systemImage: type.sfSymbol, selection: .type(type), currentSelection: selection, count: itemCounts[.type(type)] ?? 0)
            }
        case .organizations:
            if organizationExplorerLayout == .dropdown,
               let organization = selectedOrganization {
                selectedOrganizationRows(organization)
            } else {
                ForEach(organizations) { org in
                    let orgCollections = collections.filter { $0.organizationId == org.id }
                    OrgDisclosureRow(
                        org: org,
                        collections: orgCollections,
                        itemCounts: itemCounts,
                        currentSelection: selection,
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
            }
        case .trash:
            SidebarRowView(title: "Trash", systemImage: "trash", selection: .trash, currentSelection: selection, count: itemCounts[.trash] ?? 0)
        }
    }

    @ViewBuilder
    private func selectedOrganizationRows(_ organization: Organization) -> some View {
        if creatingCollectionInOrg == organization.id {
            TextField("Collection name", text: $newCollectionName, onCommit: {
                commitCreateCollection(in: organization.id)
            })
            .focused($isNewCollectionFocused)
            .tag(SidebarSelection.newCollection(organizationId: organization.id))
            .onExitCommand {
                creatingCollectionInOrg = nil
                newCollectionName = ""
            }
        }

        ForEach(CollectionTreeNode.buildTree(from: selectedOrganizationCollections)) { node in
            CollectionTreeRow(
                node: node,
                org: organization,
                itemCounts: itemCounts,
                currentSelection: selection,
                renamingCollectionId: $renamingCollectionId,
                renamingCollectionOrgId: $renamingCollectionOrgId,
                collectionRenameText: $collectionRenameText,
                isCollectionRenameFocused: $isCollectionRenameFocused,
                onRenameCollection: { id, name in
                    onRenameCollection?(id, organization.id, name)
                },
                onDeleteCollection: { collection in
                    collectionToDelete = collection
                    showDeleteCollectionAlert = true
                }
            )
        }

        if selectedOrganizationCollections.isEmpty
            && creatingCollectionInOrg != organization.id {
            Text("No collections")
                .font(Typography.listSubtitle)
                .foregroundStyle(.secondary)
                .tag(SidebarSelection?.none)
        }
    }

    private func commitCreate() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreatingFolder = false
        selection = nil
        guard !trimmed.isEmpty else { return }
        onCreateFolder?(trimmed)
    }

    private func commitCreateCollection(in organizationId: String) {
        let trimmed = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        creatingCollectionInOrg = nil
        newCollectionName = ""
        guard !trimmed.isEmpty else { return }
        onCreateCollection?(trimmed, organizationId)
    }
}

// MARK: - FolderTreeRow

/// Recursive tree row: renders a DisclosureGroup for nodes with children,
/// or a plain folder row for leaf nodes.
private struct FolderTreeRow: View {
    let node: FolderTreeNode
    let itemCounts: [SidebarSelection: Int]
    let currentSelection: SidebarSelection?
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
                        currentSelection: currentSelection,
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
            // Real folder - selectable, droppable
            FolderRowLabel(
                folder: folder,
                displayName: node.name,
                count: itemCounts[.folder(folder.id)] ?? 0,
                isSelected: currentSelection == .folder(folder.id),
                onRename: {
                    renameText = node.name
                    renamingFolderId = folder.id
                    isRenameFocused = true
                },
                onDelete: { onDeleteFolder(folder) },
                onDrop: { ids in onDropItems(ids, folder.id) }
            )
        } else {
            // Virtual parent - not selectable, no drop, no context menu
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
    let isSelected: Bool
    var onRename: () -> Void
    var onDelete: () -> Void
    var onDrop: ([String]) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isDropTargeted = false
    @State private var isHovered = false

    var body: some View {
        Label(displayName ?? folder.name, systemImage: "folder")
            .font(Typography.sidebarRow)
            .badge(count)
            .tag(SidebarSelection.folder(folder.id))
            .listRowBackground(
                RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                    .fill(
                        isDropTargeted
                            ? Color.accentColor.opacity(Opacity.dropTarget(contrast))
                            : isHovered && !isSelected
                                ? Color.primary.opacity(Opacity.itemRowHover(contrast))
                                : Color.clear
                    )
                    .padding(.horizontal, Spacing.itemHighlightHorizontalMargin)
            )
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
            .onHover { hovering in
                optionalAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
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
    let currentSelection: SidebarSelection?
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
                    currentSelection: currentSelection,
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
        .modifier(SidebarRowHoverModifier(isSelected: currentSelection == .organization(org.id)))
    }

    @ViewBuilder
    private var orgHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(org.name, systemImage: "building.2")
                .font(Typography.sidebarRow)
            Spacer()
            if org.canManageCollections {
                Button {
                    newCollectionName = ""
                    creatingCollectionInOrg = org.id
                    isExpanded = true
                    isNewCollectionFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                }
                .buttonStyle(.plain)
                .help("New Collection")
                .accessibilityLabel("New Collection")
                .padding(.trailing, 2)
                .offset(y: -4)
            }
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
    let currentSelection: SidebarSelection?
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
                        currentSelection: currentSelection,
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
                .modifier(SidebarRowHoverModifier(isSelected: currentSelection == .collection(col.id)))
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
            // Virtual parent node - not selectable, no context menu
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
    let currentSelection: SidebarSelection?
    let count:       Int

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(Typography.sidebarRow)
            .badge(count)
            .tag(selection)
            .modifier(SidebarRowHoverModifier(isSelected: currentSelection == selection))
    }
}

private struct SidebarRowHoverModifier: ViewModifier {
    let isSelected: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .listRowBackground(
                RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                    .fill(
                        isHovered && !isSelected
                            ? Color.primary.opacity(Opacity.itemRowHover(contrast))
                            : Color.clear
                    )
                    .padding(.horizontal, Spacing.itemHighlightHorizontalMargin)
            )
            .onHover { hovering in
                optionalAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}
