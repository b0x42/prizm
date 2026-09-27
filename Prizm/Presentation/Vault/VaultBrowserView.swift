import SwiftUI
import os.log

// MARK: - VaultBrowserView

/// Three-pane vault browser using `NavigationSplitView`.
///
/// - Sidebar:  `SidebarView` (categories + counts)
/// - Content:  `ItemListView` with native search and `+` button
/// - Detail:   `ItemDetailView` with Edit / Delete buttons
struct VaultBrowserView: View {

    @ObservedObject var viewModel: VaultBrowserViewModel
    let faviconLoader: FaviconLoader
    let totpCodeGenerator: any TOTPCodeGenerating
    let makeEditViewModel: (VaultItem) -> ItemEditViewModel
    let makeCreateViewModel: (ItemType, String?) -> ItemEditViewModel
    let makeMoveViewModel: ([VaultItem]) -> ItemTransferViewModel
    let makeDuplicateViewModel: ([VaultItem]) -> ItemTransferViewModel
    /// Factory for creating `AttachmentAddViewModel` - injected from AppContainer to
    /// keep the Presentation layer decoupled from the Data layer (Constitution §II).
    var makeAddAttachmentViewModel: ((String) -> AttachmentAddViewModel)? = nil
    /// Factory for creating `AttachmentBatchViewModel` - injected from AppContainer.
    var makeBatchAttachmentViewModel: ((String) -> AttachmentBatchViewModel)? = nil
    /// Factory for `AttachmentRowViewModel` - injected from AppContainer.
    var makeAttachmentRowViewModel: ((String, Attachment) -> AttachmentRowViewModel)? = nil

    @State private var showPermanentDeleteAlert = false
    @State private var showSoftDeleteAlert = false
    @State private var showDeleteFolderAlert = false
    @State private var folderToDelete: Folder?
    @State private var detailMoveViewModel: ItemTransferViewModel?
    @State private var detailDuplicateViewModel: ItemTransferViewModel?
    @State private var searchDraftQuery = ""
    @State private var selectedSearchSuggestionID: String?
    @State private var isShowAllSearchSelected = false
    @State private var hoveredSearchSuggestionID: String?
    @State private var isShowAllSearchHovered = false
    @State private var pendingItemSelectionIDs: Set<String>?
    @State private var editCloseTrigger = 0
    @State private var createViewModel: ItemEditViewModel?
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage(PreferenceKeys.organizationExplorerLayout)
    private var organizationExplorerLayout: OrganizationExplorerLayout = .tree
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(SecretVisibilityState.self) private var secretVisibility

    private let logger = Logger(subsystem: "com.prizm", category: "UI.VaultBrowser")

    private var vaultSplitView: some View {
        NavigationSplitView {
            sidebarPane
                .simultaneousGesture(
                    TapGesture().onEnded { dismissSearchSuggestions() }
                )
        } detail: {
            VStack(spacing: 0) {
                sharedSearchBar
                Divider()
                    .overlay(DesignColor.paneDivider)
                HSplitView {
                    itemListPane
                        .frame(
                            minWidth: VaultLayoutMetrics.itemListMinimumWidth,
                            idealWidth: VaultLayoutMetrics.itemListIdealWidth,
                            maxWidth: VaultLayoutMetrics.itemListMaximumWidth
                        )
                    detailPane
                        .frame(minWidth: VaultLayoutMetrics.detailMinimumWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Not `allowsHitTesting(false)`: toggling it on this AppKit-backed subtree
                // re-hosts the list and shifted it under the sidebar. Clicks outside the
                // dropdown are swallowed by the backdrop in the overlay below; hover
                // feedback is muted via the environment (see `HoverSuppressedKey`).
                .environment(\.isHoverSuppressed, shouldShowSearchSuggestions)
                .simultaneousGesture(
                    TapGesture().onEnded { dismissSearchSuggestions() }
                )
                .overlay(alignment: .topLeading) {
                    if shouldShowSearchSuggestions {
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismissSearchSuggestions()
                                }
                                .accessibilityHidden(true)

                            searchSuggestionsDropdown
                                .padding(.horizontal, Spacing.rowHorizontal)
                                .containerRelativeFrame(.horizontal) { width, _ in
                                    width * VaultLayoutMetrics.searchSuggestionsWidthRatio
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The window uses `.hiddenTitleBar`, so the title bar only hosts the traffic
            // lights (over the sidebar). Let the search bar row reclaim that strip on the
            // detail side so content starts flush with the top edge of the window.
            .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        // `.hidden` with an explicit `.windowToolbar` placement leaves the split view's
        // NSToolbar visible (52 pt strip) on macOS 26; the automatic placement actually hides it.
        .toolbarVisibility(.hidden)
    }

    private var sidebarPane: some View {
        VStack(spacing: 0) {
            SidebarView(
                selection: Binding(
                    get: { viewModel.isGlobalSearch ? nil : viewModel.sidebarSelection },
                    set: { newValue in
                        if let value = newValue {
                            viewModel.sidebarSelection = value
                        }
                    }
                ),
                navigationContext: $viewModel.navigationContext,
                organizationExplorerLayout: organizationExplorerLayout,
                itemCounts: viewModel.itemCounts,
                folders: viewModel.folders,
                organizations: viewModel.organizations,
                collections: viewModel.collections,
                onCreateFolder: { name in viewModel.createFolder(name: name) },
                onRenameFolder: { id, name in viewModel.renameFolder(id: id, name: name) },
                onDeleteFolder: { folder in
                    folderToDelete = folder
                    showDeleteFolderAlert = true
                },
                onDropItems: { ids, folderId in
                    viewModel.moveItemsToFolder(itemIds: ids, folderId: folderId)
                },
                onCreateCollection: { name, orgId in
                    viewModel.createCollection(name: name, organizationId: orgId)
                },
                onRenameCollection: { id, orgId, name in
                    viewModel.renameCollection(id: id, organizationId: orgId, name: name)
                },
                onDeleteCollection: { id, orgId in
                    viewModel.deleteCollection(id: id, organizationId: orgId)
                }
            )
            HStack(spacing: 0) {
                SyncStatusView(label: viewModel.syncStatusLabel)
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Settings")
                .accessibilityIdentifier(AccessibilityID.Vault.settingsButton)
                .padding(.trailing, Spacing.sidebarHorizontal)
                .padding(.bottom, Spacing.sidebarStatusBottom)
            }
        }
        .disabled(viewModel.isEditingItem)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationSplitViewColumnWidth(
            min: VaultLayoutMetrics.sidebarMinimumWidth,
            ideal: VaultLayoutMetrics.sidebarIdealWidth,
            max: VaultLayoutMetrics.sidebarMaximumWidth
        )
    }

    private var sharedSearchBar: some View {
        HStack(spacing: Spacing.headerGap) {
            HStack(spacing: Spacing.headerGap) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search vault", text: $searchDraftQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .onSubmit { commitSelectedSearchSuggestionOrShowAll() }
                    .onKeyPress(keys: [.return]) { keyPress in
                        guard keyPress.modifiers.contains(.command) else { return .ignored }
                        commitSelectedSearchSuggestionOrShowAll()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        moveSearchSuggestion(by: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSearchSuggestion(by: -1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        cancelSearch()
                        return .handled
                    }
                    .accessibilityLabel("Search vault")

                if !searchDraftQuery.isEmpty {
                    Button {
                        cancelSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Search")
                    .accessibilityLabel("Clear Search")
                }
            }
            .padding(.horizontal, Spacing.rowHorizontal)
            .frame(height: VaultLayoutMetrics.searchControlHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFieldFocused = true
            }
            .background(.background, in: RoundedRectangle(
                cornerRadius: VaultLayoutMetrics.searchCornerRadius
            ))
            .overlay {
                RoundedRectangle(cornerRadius: VaultLayoutMetrics.searchCornerRadius)
                    .stroke(
                        isSearchFieldFocused
                            ? Color.accentColor
                            : Color.secondary.opacity(
                                Opacity.contextPickerBorder(contrast, isHovered: false)
                            ),
                        lineWidth: isSearchFieldFocused
                            ? VaultLayoutMetrics.searchFocusedBorderWidth
                            : VaultLayoutMetrics.searchBorderWidth
                    )
                    .allowsHitTesting(false)
            }
            newItemMenu
                .simultaneousGesture(
                    TapGesture().onEnded { dismissSearchSuggestions() }
                )
        }
        .padding(.horizontal, Spacing.rowHorizontal)
        .padding(.vertical, Spacing.rowVertical)
        .background(.bar)
    }

    private var shouldShowSearchSuggestions: Bool {
        let draft = searchDraftQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return isSearchFieldFocused && !draft.isEmpty && draft != viewModel.searchQuery
    }

    private var searchSuggestionsDropdown: some View {
        VStack(spacing: 0) {
            if viewModel.searchSuggestions.isEmpty {
                Text("No matching items")
                    .font(Typography.fieldValue)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.rowHorizontal)
                    .padding(.vertical, Spacing.rowVertical)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.searchSuggestions.prefix(
                        VaultLayoutMetrics.maximumVisibleSearchSuggestions
                    ))) { item in
                        Button {
                            commitSearch(selecting: item)
                        } label: {
                            ItemRowView(
                                item: item,
                                faviconLoader: faviconLoader,
                                searchQuery: searchDraftQuery,
                                orgName: viewModel.organizations.first {
                                    $0.id == item.organizationId
                                }?.name,
                                isEmphasized: selectedSearchSuggestionID == item.id
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.rowHorizontal)
                            .background(
                                RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                                    .fill(
                                        selectedSearchSuggestionID == item.id
                                            ? Color.accentColor
                                            : hoveredSearchSuggestionID == item.id
                                                ? Color.primary.opacity(Opacity.itemRowHover(contrast))
                                                : Color.clear
                                    )
                                    .padding(.horizontal, Spacing.itemHighlightHorizontalMargin)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                hoveredSearchSuggestionID = item.id
                            } else if hoveredSearchSuggestionID == item.id {
                                hoveredSearchSuggestionID = nil
                            }
                        }
                        .accessibilityValue(
                            selectedSearchSuggestionID == item.id ? "Selected" : "Not selected"
                        )
                    }
                }
            }

            Divider()

            Button {
                commitSearch()
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Show All Matching Items")
                    Spacer()
                    Text("\(viewModel.searchSuggestions.count)")
                        .foregroundStyle(.secondary)
                }
                .font(Typography.fieldValue)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.rowHorizontal)
            .padding(.vertical, Spacing.rowVertical)
            .background(
                RoundedRectangle(cornerRadius: Spacing.contextPickerCornerRadius)
                    .fill(
                        isShowAllSearchSelected
                            ? Color.accentColor
                            : isShowAllSearchHovered
                                ? Color.primary.opacity(Opacity.itemRowHover(contrast))
                            : Color.clear
                    )
                    .padding(.horizontal, Spacing.itemHighlightHorizontalMargin)
            )
            .padding(.top, Spacing.headerGap)
            .padding(.bottom, Spacing.headerGap)
            .onHover { isShowAllSearchHovered = $0 }
            .accessibilityLabel(
                "Show all \(viewModel.searchSuggestions.count) matching items"
            )
            .accessibilityValue(isShowAllSearchSelected ? "Selected" : "Not selected")
        }
        .padding(.top, Spacing.headerGap)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: VaultLayoutMetrics.searchCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: VaultLayoutMetrics.searchCornerRadius)
                .stroke(
                    Color.secondary.opacity(
                        Opacity.contextPickerBorder(contrast, isHovered: false)
                    ),
                    lineWidth: VaultLayoutMetrics.searchBorderWidth
                )
        }
        .shadow(radius: VaultLayoutMetrics.searchSuggestionsShadowRadius)
    }

    private func commitSearch(selecting item: VaultItem? = nil) {
        let query = searchDraftQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchDraftQuery = query
        selectedSearchSuggestionID = nil
        isShowAllSearchSelected = false
        hoveredSearchSuggestionID = nil
        viewModel.activateGlobalSearch()
        viewModel.searchQuery = query
        if let item {
            viewModel.openSearchSuggestion(item)
        }
        isSearchFieldFocused = false
    }

    private func commitSelectedSearchSuggestionOrShowAll() {
        if let selectedSearchSuggestionID,
           let item = visibleSearchSuggestions.first(where: {
               $0.id == selectedSearchSuggestionID
           }) {
            commitSearch(selecting: item)
        } else {
            commitSearch()
        }
    }

    private var visibleSearchSuggestions: [VaultItem] {
        Array(viewModel.searchSuggestions.prefix(
            VaultLayoutMetrics.maximumVisibleSearchSuggestions
        ))
    }

    private func moveSearchSuggestion(by offset: Int) {
        let suggestions = visibleSearchSuggestions

        let currentIndex: Int?
        if isShowAllSearchSelected {
            currentIndex = suggestions.count
        } else if let currentSuggestionID = selectedSearchSuggestionID {
            currentIndex = suggestions.firstIndex {
                $0.id == currentSuggestionID
            }
        } else {
            currentIndex = nil
        }

        let nextIndex: Int
        if let currentIndex {
            nextIndex = min(max(currentIndex + offset, 0), suggestions.count)
        } else {
            nextIndex = offset > 0 ? 0 : suggestions.count
        }

        if nextIndex == suggestions.count {
            selectedSearchSuggestionID = nil
            isShowAllSearchSelected = true
            return
        }

        selectedSearchSuggestionID = suggestions[nextIndex].id
        isShowAllSearchSelected = false
    }

    private func clearSearch() {
        searchDraftQuery = ""
        if viewModel.isGlobalSearch {
            viewModel.deactivateGlobalSearch()
        } else {
            viewModel.searchQuery = ""
        }
    }

    private func cancelSearch() {
        clearSearch()
        selectedSearchSuggestionID = nil
        isShowAllSearchSelected = false
        hoveredSearchSuggestionID = nil
        isSearchFieldFocused = false
    }

    private func dismissSearchSuggestions() {
        selectedSearchSuggestionID = nil
        isShowAllSearchSelected = false
        hoveredSearchSuggestionID = nil
        isSearchFieldFocused = false
    }

    @ViewBuilder
    private var itemListPane: some View {
        VStack(spacing: 0) {
            syncErrorBanner
            if viewModel.isLoadingItems {
                ProgressView()
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .accessibilityLabel("Loading items")
            } else if viewModel.sidebarSelection == .trash {
                TrashView(
                    items:             viewModel.displayedItems,
                    selection:         $viewModel.itemSelection,
                    faviconLoader:     faviconLoader,
                    onRestore:         { id in await viewModel.performRestore(id: id) },
                    onPermanentDelete: { id in await viewModel.performPermanentDelete(id: id) }
                )
                .disabled(viewModel.isEditingItem)
            } else {
                ItemListView(
                    items: viewModel.displayedItems,
                    selection: Binding(
                        get: { viewModel.selectedItemIDs },
                        set: { requestedSelection in
                            if viewModel.isEditingItem {
                                pendingItemSelectionIDs = requestedSelection
                                editCloseTrigger += 1
                            } else {
                                viewModel.updateItemSelection(requestedSelection)
                            }
                        }
                    ),
                    faviconLoader: faviconLoader,
                    searchQuery: viewModel.searchQuery.isEmpty ? nil : viewModel.searchQuery,
                    onClearSearch: { clearSearch() },
                    organizations: viewModel.organizations,
                    onDelete: { id in await viewModel.performSoftDelete(id: id) },
                    onToggleFavorite: { viewModel.toggleFavorite(item: $0) },
                    onAddToFavorites: { viewModel.addToFavorites(items: $0) },
                    onDeleteItems: { await viewModel.performSoftDelete(items: $0) },
                    onEdit: { viewModel.triggerEdit(item: $0) },
                    makeMoveViewModel: makeMoveViewModel,
                    makeDuplicateViewModel: makeDuplicateViewModel
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var detailPane: some View {
        VStack(spacing: 0) {
            if let createViewModel {
                ItemEditView(
                    viewModel: createViewModel,
                    onClose: closeCreateEditor,
                    closeTrigger: editCloseTrigger,
                    onCloseRequestCancelled: {
                        pendingItemSelectionIDs = nil
                    }
                )
            } else {
                if let item = viewModel.itemSelection, !viewModel.isEditingItem {
                    detailActionBar(for: item)
                }

                ItemDetailView(
                    item:                           viewModel.itemSelection,
                    faviconLoader:                  faviconLoader,
                    totpCodeGenerator:              totpCodeGenerator,
                    folders:                        viewModel.folders,
                    organizations:                  viewModel.organizations,
                    onCopy:                         { viewModel.copy($0) },
                    makeEditViewModel:              makeEditViewModel,
                    makeAddAttachmentViewModel:     makeAddAttachmentViewModel,
                    makeBatchAttachmentViewModel:   makeBatchAttachmentViewModel,
                    makeAttachmentRowViewModel:     makeAttachmentRowViewModel,
                    onAttachmentsChanged:           { viewModel.refreshItemSelection() },
                    onEditModeChanged:              { isEditing in
                        viewModel.setItemEditing(isEditing)
                        if !isEditing, let pendingItemSelectionIDs {
                            self.pendingItemSelectionIDs = nil
                            viewModel.updateItemSelection(pendingItemSelectionIDs)
                        }
                    },
                    onSoftDelete:                   { id in await viewModel.performSoftDelete(id: id) },
                    onRestore:                      { id in await viewModel.performRestore(id: id) },
                    onPermanentDelete:              { id in await viewModel.performPermanentDelete(id: id) },
                    editTrigger:                    viewModel.editTrigger,
                    saveTrigger:                    viewModel.saveTrigger,
                    editCloseTrigger:               editCloseTrigger,
                    onEditCloseRequestCancelled:    {
                        pendingItemSelectionIDs = nil
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var body: some View {
        vaultSplitView
        .alert("Action Failed", isPresented: Binding(
            get:  { viewModel.actionError != nil },
            set:  { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Delete Permanently?", isPresented: $showPermanentDeleteAlert) {
            Button("Delete Permanently", role: .destructive) {
                if let item = viewModel.itemSelection {
                    Task { await viewModel.performPermanentDelete(id: item.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(viewModel.itemSelection?.name ?? "")\" will be permanently deleted and cannot be recovered.")
        }
        .alert("Move to Trash?", isPresented: $showSoftDeleteAlert) {
            Button("Move to Trash", role: .destructive) {
                if let item = viewModel.itemSelection {
                    Task { await viewModel.performSoftDelete(id: item.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(viewModel.itemSelection?.name ?? "")\" will be moved to Trash.")
        }
        .alert("Delete Folder?", isPresented: $showDeleteFolderAlert) {
            Button("Delete Folder", role: .destructive) {
                if let folder = folderToDelete {
                    viewModel.deleteFolder(id: folder.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items in \"\(folderToDelete?.name ?? "")\" will not be deleted. They will become unfoldered.")
        }
        .accessibilityIdentifier(AccessibilityID.Vault.navigationSplit)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onChange(of: viewModel.sidebarSelection) { _, newValue in
            if newValue == .trash {
                viewModel.searchQuery = ""
            }
        }
        .onChange(of: viewModel.itemSelection?.id) {
            secretVisibility.concealAll()
        }
        .onChange(of: organizationExplorerLayout) { _, layout in
            if layout == .tree {
                viewModel.navigationContext = .allVaults
            }
        }
        .onChange(of: searchDraftQuery) { _, query in
            selectedSearchSuggestionID = nil
            isShowAllSearchSelected = false
            viewModel.updateSearchSuggestions(query: query)
        }
        .onReceive(viewModel.$searchSuggestions) { suggestions in
            guard shouldShowSearchSuggestions else { return }
            selectedSearchSuggestionID = suggestions.first?.id
            isShowAllSearchSelected = false
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            if newValue.isEmpty && viewModel.isGlobalSearch {
                viewModel.deactivateGlobalSearch()
            }
        }
        .onChange(of: viewModel.isGlobalSearch) { _, isActive in
            if !isActive { isSearchFieldFocused = false }
        }
        .onChange(of: viewModel.isEditingItem) { _, isEditing in
            if isEditing { isSearchFieldFocused = false }
        }
        .onChange(of: viewModel.syncErrorMessage) { _, newMessage in
            if let message = newMessage {
                AccessibilityNotification.Announcement(message).post()
            }
        }
        .onChange(of: viewModel.actionError) { _, newError in
            if let error = newError {
                AccessibilityNotification.Announcement(error).post()
            }
        }
        .onChange(of: viewModel.createItemType) { _, type in
            guard let type else { return }
            createViewModel = makeCreateViewModel(
                type,
                viewModel.selectedCollectionId ?? viewModel.selectedFolderId
            )
            viewModel.setItemEditing(true)
        }
        .onChange(of: viewModel.saveTrigger) {
            createViewModel?.save()
        }
        .background {
            Button("") {
                isSearchFieldFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .sheet(item: $detailMoveViewModel) { transferViewModel in
            MoveItemSheet(viewModel: transferViewModel)
        }
        .sheet(item: $detailDuplicateViewModel) { transferViewModel in
            DuplicateItemSheet(viewModel: transferViewModel)
        }
        .onDisappear {
            secretVisibility.concealAll()
        }
    }

    private func closeCreateEditor() {
        createViewModel = nil
        viewModel.createItemType = nil
        viewModel.setItemEditing(false)
        if let pendingItemSelectionIDs {
            self.pendingItemSelectionIDs = nil
            viewModel.updateItemSelection(pendingItemSelectionIDs)
        }
    }

    private var newItemMenu: some View {
        Menu {
            ForEach(ItemType.allCases) { type in
                Button {
                    viewModel.createItemType = type
                } label: {
                    Label(type.displayName, systemImage: type.sfSymbol)
                }
            }
        } label: {
            HStack(spacing: Spacing.headerGap) {
                Label("New Item", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                Image(systemName: "chevron.down")
                    .font(Typography.utility)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.rowHorizontal)
            .frame(height: VaultLayoutMetrics.searchControlHeight)
            .foregroundStyle(.white)
            .background(
                Color.accentColor,
                in: RoundedRectangle(cornerRadius: VaultLayoutMetrics.searchCornerRadius)
            )
        }
        .buttonStyle(.plain)
        .help("New Item (⌘N)")
        .accessibilityLabel("New Item")
        .accessibilityIdentifier(AccessibilityID.Create.newItemButton)
        .disabled(viewModel.isEditingItem)
        .menuIndicator(.hidden)
        .background {
            Button("") { viewModel.createItemType = .login }
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    @ViewBuilder
    private func detailActionBar(for item: VaultItem) -> some View {
        HStack(spacing: Spacing.headerGap) {
            ItemLocationBreadcrumb(
                vaultName: item.organizationId.map { organizationID in
                    viewModel.organizations.first {
                        $0.id == organizationID
                    }?.name ?? "Organization"
                } ?? "My Vault",
                isPersonalVault: item.organizationId == nil,
                folderName: viewModel.folders.first {
                    $0.id == item.folderId
                }?.name,
                itemType: itemType(for: item)
            )

            Spacer()

            if item.isDeleted {
                Button("Restore") {
                    Task { await viewModel.performRestore(id: item.id) }
                }
                .accessibilityIdentifier(AccessibilityID.Trash.restoreButton)

                Button("Delete Permanently", role: .destructive) {
                    showPermanentDeleteAlert = true
                }
                .foregroundStyle(.red)
                .accessibilityIdentifier(AccessibilityID.Trash.permanentDeleteButton)
            } else {
                Button {
                    viewModel.toggleFavorite(item: item)
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isFavorite ? "Unfavorite" : "Favorite")
                .accessibilityLabel(item.isFavorite ? "Unfavorite" : "Favorite")
                .accessibilityValue(item.isFavorite ? "Favorited" : "Not favorited")

                Button {
                    viewModel.triggerEdit()
                } label: {
                    HStack(spacing: Spacing.headerGap) {
                        Text("Edit")
                        Image(systemName: "pencil")
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .accessibilityLabel("Edit")
                .accessibilityIdentifier(AccessibilityID.Edit.editButton)

                Menu {
                    Button("Move…", systemImage: "folder") {
                        detailMoveViewModel = makeMoveViewModel([item])
                    }
                    Button("Duplicate…", systemImage: "plus.square.on.square") {
                        detailDuplicateViewModel = makeDuplicateViewModel([item])
                    }

                    Divider()

                    Button("Copy Item ID", systemImage: "doc.on.doc") {
                        viewModel.copy(item.id)
                    }

                    Divider()

                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showSoftDeleteAlert = true
                    }
                } label: {
                    Text("More  \(Image(systemName: "ellipsis"))")
                }
                .menuIndicator(.hidden)
                .help("More item actions")
                .accessibilityLabel("More item actions")
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
        .frame(height: LayoutMetrics.paneActionBarHeight)
        .background(.bar)
    }

    private func itemType(for item: VaultItem) -> ItemType {
        switch item.content {
        case .login:      return .login
        case .card:       return .card
        case .identity:   return .identity
        case .secureNote: return .secureNote
        case .sshKey:     return .sshKey
        }
    }

    // MARK: - Sync Error Banner

    @ViewBuilder
    private var syncErrorBanner: some View {
        if let message = viewModel.syncErrorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(Typography.bannerText)
                Spacer()
                Button {
                    viewModel.dismissSyncError()
                } label: {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier(AccessibilityID.Vault.syncErrorDismiss)
            }
            .padding(.horizontal, Spacing.bannerHorizontal)
            .padding(.vertical, Spacing.bannerVertical)
            .background(Color.yellow.opacity(Opacity.bannerBackground(contrast)))
            .frame(maxHeight: 44)
            .accessibilityIdentifier(AccessibilityID.Vault.syncErrorBanner)
        }
    }
}

struct ItemLocationBreadcrumb: View {
    let vaultName: String
    let isPersonalVault: Bool
    let folderName: String?
    let itemType: ItemType

    var body: some View {
        HStack(spacing: Spacing.headerGap) {
            Label(
                vaultName,
                systemImage: isPersonalVault ? "person.crop.circle" : "building.2"
            )

            if folderName != nil {
                Text("|")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            if let folderName {
                Label(folderName, systemImage: "folder")
            }

            Text("|")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Label(itemType.displayName, systemImage: itemType.sfSymbol)
        }
        .font(Typography.fieldValue)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

private enum VaultLayoutMetrics {
    static let sidebarMinimumWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 210
    static let sidebarMaximumWidth: CGFloat = 480
    static let itemListMinimumWidth: CGFloat = 220
    static let itemListIdealWidth: CGFloat = 280
    static let itemListMaximumWidth: CGFloat = 420
    static let detailMinimumWidth: CGFloat = 320
    static let searchCornerRadius: CGFloat = 7
    static let searchBorderWidth: CGFloat = 1
    static let searchFocusedBorderWidth: CGFloat = 2
    static let searchControlHeight: CGFloat = 32
    static let maximumVisibleSearchSuggestions = 6
    static let searchSuggestionsWidthRatio: CGFloat = 0.4
    static let searchSuggestionsShadowRadius: CGFloat = 8
}
