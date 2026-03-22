import SwiftUI

// MARK: - CardBackground

/// A `ViewModifier` that renders any view inside a card-style container:
/// rounded corners, a named background color that adapts for light/dark mode,
/// and a soft drop shadow.
///
/// Adapted from: https://danijelavrzan.com/posts/2023/02/card-view-swiftui/
///
/// The background uses the `CardBackground` named color asset (white in light mode,
/// dark gray #212121 in dark mode). A black shadow on a dark background is invisible,
/// so shifting the card background ensures the shadow remains effective in both
/// appearances without requiring `@Environment(\.colorScheme)` logic here.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color("CardBackground"))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}

extension View {
    /// Applies the card background modifier: rounded corners, adaptive background, and shadow.
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}

// MARK: - DetailSectionCard

/// A card-style section container for vault item detail views.
///
/// Renders an optional section header label above a group of field rows,
/// all wrapped in a `cardBackground()`. Used by all five type-specific detail
/// views to group related fields visually.
///
/// Usage:
/// ```swift
/// DetailSectionCard("Credentials") {
///     FieldRowView(label: "Username", ...)
///     Divider()
///     FieldRowView(label: "Password", ...)
/// }
/// ```
struct DetailSectionCard<Content: View>: View {

    private let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if Self.hasHeader(title) {
                Text(title!)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .accessibilityIdentifier(
                        AccessibilityID.Detail.cardHeader(title!)
                    )
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.vertical, 6)
            .cardBackground()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Testable header logic

    /// Returns `true` when the card should render a visible section header.
    ///
    /// A nil or whitespace-only title means no header is rendered — the card
    /// appears without a label above it.
    static func hasHeader(_ title: String?) -> Bool {
        guard let title else { return false }
        return !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
