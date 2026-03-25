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
    var onEditSheetState: ((Bool) -> Void)? = nil

    @State private var showSoftDeleteAlert = false
    @State private var showPermanentDeleteAlert = false

    private let logger = Logger(subsystem: "com.macwarden", category: "UI.VaultBrowser")

    var body: some View {
        NavigationSplitView(
            sidebar: {
                SidebarView(
                    selection:  $viewModel.sidebarSelection,
                    itemCounts: viewModel.itemCounts
                )
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
                            onDelete:      { id in await viewModel.performSoftDelete(id: id) }
                        )
                    }
                }
                .searchable(
                    text: $viewModel.searchQuery,
                    placement: .sidebar,
                    prompt: "Search vault"
                )
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if viewModel.sidebarSelection != .trash {
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
                }
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            },
            detail: {
                ItemDetailView(
                    item:                viewModel.itemSelection,
                    faviconLoader:       faviconLoader,
                    onCopy:              { viewModel.copy($0) },
                    makeEditViewModel:   makeEditViewModel,
                    onEditSheetChanged:  { open in
                        viewModel.handleEditSheetState(open)
                        onEditSheetState?(open)
                    },
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
                                .accessibilityIdentifier(AccessibilityID.Trash.permanentDeleteButton)
                            }
                        } else {
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
                            }
                        }
                    }
                }
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
        .accessibilityIdentifier(AccessibilityID.Vault.navigationSplit)
        .onChange(of: viewModel.sidebarSelection) { _, newValue in
            if newValue == .trash { viewModel.searchQuery = "" }
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
                    .font(.callout)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.15))
            .frame(maxHeight: 44)
            .accessibilityIdentifier(AccessibilityID.Vault.syncErrorBanner)
        }
    }
}
