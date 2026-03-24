import SwiftUI

// MARK: - VaultBrowserView

/// Three-pane vault browser (User Story 3).
///
/// Layout: `NavigationSplitView` in `.balanced` column mode.
/// - Sidebar:     `SidebarView` (categories + counts)
/// - Content/List: `ItemListView` (filtered item rows)
/// - Detail:      `ItemDetailView` (selected item detail or empty state)
///
/// Search bar in the toolbar filters `ItemListView` in real time (FR-012).
/// Sync error banner appears at the top of the content area (FR-049).
/// Last-synced timestamp in the toolbar (FR-037, FR-041).
struct VaultBrowserView: View {

    @ObservedObject var viewModel: VaultBrowserViewModel
    let faviconLoader: FaviconLoader
    /// Factory closure injected from `AppContainer` so the view layer stays decoupled from Data.
    let makeEditViewModel: (VaultItem) -> ItemEditViewModel
    /// Factory closure for creating a new item edit view model in create mode.
    let makeCreateViewModel: (ItemType) -> ItemEditViewModel
    /// Notifies the ViewModel when the edit sheet opens/closes (for menu bar state).
    var onEditSheetState: ((Bool) -> Void)? = nil

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
                        // Trash pane — shows soft-deleted items with restore/permanent-delete actions.
                        TrashView(
                            items:             viewModel.displayedItems,
                            selection:         $viewModel.itemSelection,
                            faviconLoader:     faviconLoader,
                            onRestore:         { id in await viewModel.performRestore(id: id) },
                            onPermanentDelete: { id in await viewModel.performPermanentDelete(id: id) }
                        )
                    } else {
                        ItemListView(
                            items:        viewModel.displayedItems,
                            selection:    $viewModel.itemSelection,
                            faviconLoader: faviconLoader,
                            onDelete:     { id in await viewModel.performSoftDelete(id: id) }
                        )
                    }
                }
                // .toolbar is on the always-present VStack so the ToolbarItem stays registered
                // across all category switches — removing it from ItemListView (inside the else
                // branch) caused SwiftUI to re-resolve the placement every time Trash was exited.
                //
                // Placement: .automatic rather than .primaryAction. .primaryAction follows the
                // NavigationSplitView column that currently holds keyboard focus, so clicking a
                // sidebar row moved the button to the search-bar area. .automatic resolves to a
                // stable position in the content column's portion of the unified macOS toolbar
                // regardless of which column is focused.
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        // The ToolbarItem is always present (placement stays registered), but its
                        // content switches based on Trash state. Using .disabled(true) on a macOS
                        // Menu with an image-only label causes NSMenuButton to suppress the SF
                        // Symbol while keeping the button frame visible — not truly hidden. Instead,
                        // swap the content: show an invisible placeholder in Trash so the item
                        // slot is kept, and show the real Menu with its ⌘N shortcut otherwise.
                        if viewModel.sidebarSelection == .trash {
                            // Zero-size placeholder keeps the ToolbarItem registered without
                            // rendering anything visible or interactive.
                            Color.clear
                                .frame(width: 0, height: 0)
                                .accessibilityHidden(true)
                        } else {
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
                            .help("New Item")
                            .accessibilityIdentifier(AccessibilityID.Create.newItemButton)
                            // ⌘N shortcut is only registered when not in Trash — the conditional
                            // above ensures it is never installed for Trash, so no .disabled needed.
                            .keyboardShortcut("n", modifiers: .command)
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
                    // Relay menu bar Edit/Save actions into the detail pane (spec §9.3–9.4).
                    editTrigger:         viewModel.editTrigger,
                    saveTrigger:         viewModel.saveTrigger
                )
            }
        )
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $viewModel.searchQuery, prompt: "Search vault")
        // Error alert for delete / restore failures.
        .alert("Action Failed", isPresented: Binding(
            get:  { viewModel.actionError != nil },
            set:  { if !$0 { viewModel.actionError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .accessibilityIdentifier(AccessibilityID.Vault.navigationSplit)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                lastSyncedLabel
            }
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

    // MARK: - Subviews

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

    @ViewBuilder
    private var lastSyncedLabel: some View {
        if let date = viewModel.lastSyncedAt {
            Text("Last synced: \(date, formatter: Self.relativeDateFormatter)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityID.Vault.lastSyncedLabel)
        }
    }

    // MARK: - Formatters

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
