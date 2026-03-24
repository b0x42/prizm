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
                        // The + button is embedded in the view body (not a ToolbarItem) so its
                        // position never shifts with NavigationSplitView column focus. macOS uses
                        // a single unified NSToolbar for the entire window; ToolbarItem placements
                        // like .primaryAction and .automatic resolve relative to whichever column
                        // currently holds focus, so clicking a sidebar row would drift the button
                        // to the search-bar area. Embedding it here makes it unconditionally above
                        // the list. .keyboardShortcut still works on non-toolbar views.
                        newItemBar
                        ItemListView(
                            items:        viewModel.displayedItems,
                            selection:    $viewModel.itemSelection,
                            faviconLoader: faviconLoader,
                            onDelete:     { id in await viewModel.performSoftDelete(id: id) }
                        )
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

    /// A thin action bar rendered immediately above the item list.
    ///
    /// Embedding this in the view body rather than as a ToolbarItem is intentional:
    /// macOS NavigationSplitView uses a single unified NSToolbar, and ToolbarItem
    /// placements shift based on which column holds focus — clicking a sidebar row
    /// would drift the button next to the search field. A view-body button has a
    /// fixed, stable position regardless of focus or selection state.
    @ViewBuilder
    private var newItemBar: some View {
        HStack(spacing: 0) {
            Spacer()
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
                    .imageScale(.medium)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("New Item (⌘N)")
            .accessibilityIdentifier(AccessibilityID.Create.newItemButton)
            // .keyboardShortcut works on any view — no ToolbarItem required.
            .keyboardShortcut("n", modifiers: .command)
            .padding(.trailing, Spacing.rowHorizontal)
        }
        .frame(height: 28)
        .background(.bar)
        Divider()
    }

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
