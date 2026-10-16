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

    /// Alphabetical letter sections, like the regular item list. `items` is already sorted by
    /// name, so grouping keeps the order inside each section.
    private var sections: [(letter: String, items: [VaultItem])] {
        let grouped = Dictionary(grouping: items) { item in
            let first = item.name.first.map { String($0).uppercased() } ?? "#"
            return first.first?.isLetter == true ? first : "#"
        }
        return grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return false }
            if rhs.key == "#" { return true }
            return lhs.key < rhs.key
        }.map { (letter: $0.key, items: $0.value) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No codes",
                    systemImage: "clock",
                    description: Text(searchQuery == nil
                        ? "None of your items has a code."
                        : "No codes match your search.")
                )
                .accessibilityIdentifier(AccessibilityID.VerificationCodes.emptyState)
            } else {
                // Clicking a row opens the item in the detail pane (countdown included); the hover
                // COPY label on the row copies the code.
                List(selection: $selection) {
                    ForEach(sections, id: \.letter) { section in
                        Section(header: Text(section.letter)) {
                            ForEach(section.items, id: \.id) { item in
                                row(for: item).tag(item)
                            }
                        }
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
                TOTPCodeRowView(itemId: item.id, name: item.name, state: state, showsName: true,
                                showsCountdown: false, onCopy: onCopy)
            } else {
                Text(item.name).font(.headline).lineLimit(1)
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
