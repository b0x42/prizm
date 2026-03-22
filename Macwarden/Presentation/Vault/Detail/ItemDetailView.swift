import SwiftUI

// MARK: - ItemDetailView

/// Routes to the correct type-specific detail view and shows item metadata footer.
///
/// FR-031: creation + revision dates in the footer.
/// FR-034: "No item selected" empty state when `item` is nil.
struct ItemDetailView: View {

    let item:          VaultItem?
    let faviconLoader: FaviconLoader
    let onCopy:        (String) -> Void

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                // Item name header with favicon/type icon
                HStack(alignment: .center, spacing: 12) {
                    FaviconView(
                        domain:   primaryDomain(for: item),
                        itemType: itemType(for: item),
                        loader:   faviconLoader,
                        size:     36
                    )
                    Text(item.name.isEmpty ? " " : item.name)
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier(AccessibilityID.Detail.itemName)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 12)

                // Type-specific content
                typeDetailView(for: item)

                Divider()

                // Metadata footer (FR-031)
                HStack {
                    Label(
                        "Created \(item.creationDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Label(
                        "Updated \(item.revisionDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
            }
        } else {
            ContentUnavailableView(
                "No Item Selected",
                systemImage: "square.dashed",
                description: Text("Select an item from the list.")
            )
            .accessibilityIdentifier(AccessibilityID.Detail.emptyState)
        }
    }

    // MARK: - Favicon helpers

    private func primaryDomain(for item: VaultItem) -> String? {
        guard case .login(let l) = item.content,
              let first = l.uris.first else { return nil }
        return URL(string: first.uri)?.host
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

    // MARK: - Type dispatcher

    @ViewBuilder
    private func typeDetailView(for item: VaultItem) -> some View {
        switch item.content {
        case .login(let l):
            LoginDetailView(item: item, login: l, onCopy: onCopy)

        case .card(let c):
            CardDetailView(item: item, card: c, onCopy: onCopy)

        case .identity(let i):
            IdentityDetailView(item: item, identity: i, onCopy: onCopy)

        case .secureNote(let n):
            SecureNoteDetailView(item: item, secureNote: n, onCopy: onCopy)

        case .sshKey(let k):
            SSHKeyDetailView(item: item, sshKey: k, onCopy: onCopy)
        }
    }
}
