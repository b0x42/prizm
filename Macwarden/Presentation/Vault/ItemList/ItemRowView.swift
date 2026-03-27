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
    var searchQuery:   String? = nil

    var body: some View {
        HStack(spacing: 10) {
            FaviconView(
                domain:    primaryDomain(for: item),
                itemType:  itemType(for: item),
                loader:    faviconLoader,
                size:      26
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(styledName)
                        .font(.headline)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .imageScale(.small)
                            .foregroundStyle(.yellow)
                    }
                }
                if let subtitle = subtitle(for: item) {
                    Text(styledSubtitle(subtitle))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Highlighted text helpers

    private var styledName: AttributedString {
        guard let q = searchQuery, !q.isEmpty else { return AttributedString(item.name) }
        return Self.highlightedText(item.name, query: q)
    }

    private func styledSubtitle(_ text: String) -> AttributedString {
        guard let q = searchQuery, !q.isEmpty else { return AttributedString(text) }
        return Self.highlightedText(text, query: q)
    }

    /// Returns an `AttributedString` with the first case-insensitive match of `query` rendered in bold.
    static func highlightedText(_ text: String, query: String) -> AttributedString {
        var result = AttributedString(text)
        guard !query.isEmpty,
              let range = text.range(of: query, options: .caseInsensitive) else {
            return result
        }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        let start = result.index(result.startIndex, offsetByCharacters: lower)
        let end   = result.index(result.startIndex, offsetByCharacters: upper)
        result[start..<end].inlinePresentationIntent = .stronglyEmphasized
        return result
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
