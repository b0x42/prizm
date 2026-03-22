import SwiftUI

// MARK: - ItemRowView

/// A single row in the item list, showing favicon/type-icon, name, subtitle, and favorite star.
///
/// FR-021: type-specific subtitle
///   - Login:       username
///   - Card:        `*` + last 4 digits of card number
///   - Identity:    first + last name; falls back to email; then blank (FR-046)
///   - Secure Note: first 30 chars of note body truncated with `…`
///   - SSH Key:     key fingerprint, or "[No fingerprint]" if absent (FR-047)
///
/// FR-022: favorite star indicator (display-only)
/// FR-009: favicon with SF Symbol fallback
struct ItemRowView: View {

    let item:          VaultItem
    let faviconLoader: FaviconLoader

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(
                domain:    primaryDomain(for: item),
                itemType:  itemType(for: item),
                loader:    faviconLoader
            )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(Typography.listTitle)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .imageScale(.small)
                            .foregroundStyle(.yellow)
                    }
                }
                if let subtitle = subtitle(for: item) {
                    Text(subtitle)
                        .font(Typography.listSubtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Subtitle (FR-021, FR-046, FR-047)

    private func subtitle(for item: VaultItem) -> String? {
        switch item.content {
        case .login(let l):
            return l.username

        case .card(let c):
            if let number = c.number, number.count >= 4 {
                return "*" + String(number.suffix(4))
            }
            return nil

        case .identity(let i):
            let firstName = i.firstName ?? ""
            let lastName  = i.lastName  ?? ""
            let fullName  = [firstName, lastName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !fullName.isEmpty { return fullName }
            if let email = i.email, !email.isEmpty { return email }
            return nil

        case .secureNote(let n):
            guard let notes = n.notes, !notes.isEmpty else { return nil }
            if notes.count <= 30 { return notes }
            return String(notes.prefix(30)) + "…"

        case .sshKey(let k):
            if let fp = k.keyFingerprint, !fp.isEmpty { return fp }
            return "[No fingerprint]"
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
}
