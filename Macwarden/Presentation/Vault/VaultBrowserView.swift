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
                    ItemListView(
                        items:        viewModel.displayedItems,
                        selection:    $viewModel.itemSelection,
                        faviconLoader: faviconLoader
                    )
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
                    // Relay menu bar Edit/Save actions into the detail pane (spec §9.3–9.4).
                    editTrigger:         viewModel.editTrigger,
                    saveTrigger:         viewModel.saveTrigger
                )
            }
        )
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $viewModel.searchQuery, prompt: "Search vault")
        .accessibilityIdentifier(AccessibilityID.Vault.navigationSplit)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                lastSyncedLabel
            }
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
