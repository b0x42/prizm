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
    let makeEditViewModel: (VaultItem) -> ItemEditViewModel
    let makeCreateViewModel: (ItemType) -> ItemEditViewModel

    @State private var showSoftDeleteAlert = false
    @State private var showPermanentDeleteAlert = false
    @State private var showDeleteFolderAlert = false
    @State private var folderToDelete: Folder?
    @State private var isSearchFieldFocused = false

    private let logger = Logger(subsystem: "com.prizm", category: "UI.VaultBrowser")

    var body: some View {
        NavigationSplitView(
            sidebar: {
                VStack(spacing: 0) {
                    SidebarView(
                        selection: Binding(
                            get: { viewModel.isGlobalSearch ? nil : viewModel.sidebarSelection },
                            set: { newValue in
                                if let value = newValue {
                                    Task { @MainActor in viewModel.sidebarSelection = value }
                                }
                            }
                        ),
                        itemCounts: viewModel.itemCounts,
                        folders: viewModel.folders,
                        onCreateFolder: { name in viewModel.createFolder(name: name) },
                        onRenameFolder: { id, name in viewModel.renameFolder(id: id, name: name) },
                        onDeleteFolder: { folder in
                            folderToDelete = folder
                            showDeleteFolderAlert = true
                        },
                        onDropItems: { ids, folderId in viewModel.moveItemsToFolder(itemIds: ids, folderId: folderId) }
                    )
                    SyncStatusView(label: viewModel.syncStatusLabel)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            },
            content: {
                VStack(spacing: 0) {
                    syncErrorBanner
                    if viewModel.sidebarSelection == .trash {
                        TrashView(
                            items:             viewModel.displayedItems,
                            selection:         $viewModel.itemSelection,
                            faviconLoader:     faviconLoader,
                            onRestore:         { id in await viewModel.performRestore(id: id) },
                            onPermanentDelete: { id in await viewModel.performPermanentDelete(id: id) }
                        )
                    } else {
                        ItemListView(
                            items:         viewModel.displayedItems,
                            selection:     $viewModel.itemSelection,
                            faviconLoader: faviconLoader,
                            searchQuery:   viewModel.searchQuery.isEmpty ? nil : viewModel.searchQuery,
                            onDelete:      { id in await viewModel.performSoftDelete(id: id) },
                            onToggleFavorite: { viewModel.toggleFavorite(item: $0) }
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(ItemType.allCases) { type in
                                Button {
                                    viewModel.createItemType = type
                                } label: {
                                    Label(type.displayName, systemImage: type.sfSymbol)
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Item (⌘N)")
                        .accessibilityIdentifier(AccessibilityID.Create.newItemButton)
                        .menuIndicator(.visible)
                        .background {
                            Button("") { viewModel.createItemType = .login }
                                .keyboardShortcut("n", modifiers: .command)
                                .frame(width: 0, height: 0)
                                .opacity(0)
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            },
            detail: {
                ItemDetailView(
                    item:                viewModel.itemSelection,
                    faviconLoader:       faviconLoader,
                    onCopy:              { viewModel.copy($0) },
                    makeEditViewModel:   makeEditViewModel,
                    onEditSheetChanged: { viewModel.handleEditSheetState($0) },
                    onSoftDelete:        { id in await viewModel.performSoftDelete(id: id) },
                    onRestore:           { id in await viewModel.performRestore(id: id) },
                    onPermanentDelete:   { id in await viewModel.performPermanentDelete(id: id) },
                    editTrigger:         viewModel.editTrigger,
                    saveTrigger:         viewModel.saveTrigger
                )
                .toolbar {
                    if let item = viewModel.itemSelection {
                        if item.isDeleted {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Restore") {
                                    Task { await viewModel.performRestore(id: item.id) }
                                }
                                .accessibilityIdentifier(AccessibilityID.Trash.restoreButton)
                            }
                            ToolbarItem(placement: .destructiveAction) {
                                Button("Delete Permanently", role: .destructive) {
                                    showPermanentDeleteAlert = true
                                }
                                .foregroundStyle(.red)
                                .accessibilityIdentifier(AccessibilityID.Trash.permanentDeleteButton)
                            }
                        } else {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    viewModel.toggleFavorite(item: item)
                                } label: {
                                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                                        .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                                }
                                .help(item.isFavorite ? "Unfavorite" : "Favorite")
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button("Edit") {
                                    viewModel.triggerEdit()
                                }
                                .disabled(viewModel.editSheetOpen)
                                .keyboardShortcut("e", modifiers: .command)
                                .accessibilityIdentifier(AccessibilityID.Edit.editButton)
                            }
                            ToolbarItem(placement: .destructiveAction) {
                                Button("Delete", role: .destructive) {
                                    showSoftDeleteAlert = true
                                }
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .searchable(
                    text: $viewModel.searchQuery,
                    isPresented: $isSearchFieldFocused,
                    placement: .toolbar,
                    prompt: "Search vault"
                )
            }
        )
        .navigationSplitViewStyle(.balanced)
        .alert("Action Failed", isPresented: Binding(
            get:  { viewModel.actionError != nil },
            set:  { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
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
        .alert("Delete Folder?", isPresented: $showDeleteFolderAlert) {
            Button("Delete Folder", role: .destructive) {
                if let folder = folderToDelete {
                    viewModel.deleteFolder(id: folder.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items in \"\(folderToDelete?.name ?? "")\" will not be deleted — they will become unfoldered.")
        }
        .accessibilityIdentifier(AccessibilityID.Vault.navigationSplit)
        .onChange(of: viewModel.sidebarSelection) { _, newValue in
            if newValue == .trash {
                viewModel.searchQuery = ""
            }
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            if newValue.isEmpty && viewModel.isGlobalSearch {
                viewModel.deactivateGlobalSearch()
            }
        }
        .onChange(of: viewModel.isGlobalSearch) { _, isActive in
            if !isActive { isSearchFieldFocused = false }
        }
        .background {
            Button("") {
                viewModel.activateGlobalSearch()
                isSearchFieldFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .sheet(item: $viewModel.createItemType) { type in
            ItemEditView(
                viewModel: makeCreateViewModel(type),
                isPresented: Binding(
                    get: { viewModel.createItemType != nil },
                    set: { if !$0 { viewModel.createItemType = nil } }
                )
            )
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
                .accessibilityIdentifier(AccessibilityID.Vault.syncErrorDismiss)
            }
            .padding(.horizontal, Spacing.bannerHorizontal)
            .padding(.vertical, Spacing.bannerVertical)
            .background(Color.yellow.opacity(0.15))
            .frame(maxHeight: 44)
            .accessibilityIdentifier(AccessibilityID.Vault.syncErrorBanner)
        }
    }
}
