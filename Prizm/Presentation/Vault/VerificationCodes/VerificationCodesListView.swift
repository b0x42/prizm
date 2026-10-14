import SwiftUI

// MARK: - VerificationCodesListView

/// Middle-column list for the "Verification Codes" sidebar entry (FR-004 to FR-009).
///
/// `items` arrive already filtered, searched, and sorted alphabetically by the repository.
/// One tracker keeps every visible code current; it is restarted when the items change and
/// stopped when the list goes away or the app is hidden or minimized.
struct VerificationCodesListView: View {

    let items: [VaultItem]
    @Binding var selection: VaultItem?
    let faviconLoader: FaviconLoader
    var searchQuery: String? = nil
    let onCopy: (String) -> Void

    @StateObject private var codes: TOTPCodesViewModel

    init(
        items: [VaultItem],
        selection: Binding<VaultItem?>,
        faviconLoader: FaviconLoader,
        searchQuery: String? = nil,
        makeViewModel: @escaping () -> TOTPCodesViewModel,
        onCopy: @escaping (String) -> Void
    ) {
        self.items = items
        self._selection = selection
        self.faviconLoader = faviconLoader
        self.searchQuery = searchQuery
        self.onCopy = onCopy
        _codes = StateObject(wrappedValue: makeViewModel())
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No verification codes",
                    systemImage: "clock",
                    description: Text(searchQuery == nil
                        ? "None of your items has a verification code."
                        : "No verification codes match your search.")
                )
                .accessibilityIdentifier(AccessibilityID.VerificationCodes.emptyState)
            } else {
                List(selection: $selection) {
                    ForEach(items, id: \.id) { item in
                        row(for: item).tag(item)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.VerificationCodes.list)
            }
        }
        .task(id: items) { codes.start(items: items) }
        .onDisappear { codes.stop() }
        .onAppVisibilityChange { visible in
            if visible { codes.start(items: items) } else { codes.stop() }
        }
    }

    @ViewBuilder
    private func row(for item: VaultItem) -> some View {
        HStack(spacing: 10) {
            FaviconView(domain: primaryDomain(for: item), itemType: .login, loader: faviconLoader, size: 26)
            if let state = codes.states[item.id] {
                TOTPCodeRowView(itemId: item.id, name: item.name, state: state, showsName: true, onCopy: onCopy)
            } else {
                Text(item.name).font(Typography.listTitle).lineLimit(1)
                Spacer()
            }
        }
        .padding(.vertical, 6)
    }

    private func primaryDomain(for item: VaultItem) -> String? {
        guard case .login(let l) = item.content, let first = l.uris.first else { return nil }
        return URL(string: first.uri)?.host
    }
}
