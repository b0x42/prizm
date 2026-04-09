import SwiftUI

// MARK: - Typography
//
// All font roles for the Prizm Presentation layer.
//
// Use these constants instead of raw `.font(...)` values to keep
// the type scale consistent across every view. Change a role here
// and every consumer updates automatically.
//
// macOS type scale reference (approximate pt sizes at default size):
//   .largeTitle 26 · .title 22 · .title2 17 · .title3 15
//   .headline 13 semibold · .body 13 · .callout 12
//   .subheadline 11 · .footnote 10 · .caption 10
enum Typography {
    /// Item name in the detail pane — the largest text on screen.
    static let pageTitle: Font     = .largeTitle.bold()

    /// Card section headings ("Credentials", "Websites") — clearly above body text.
    static let sectionHeader: Font = .title3

    /// Primary field content — the value the user cares about.
    static let fieldValue: Font    = .body

    /// Small label rendered above a field value.
    static let fieldLabel: Font    = .subheadline

    /// Utility text: COPY button, footer dates, metadata.
    static let utility: Font       = .caption

    /// Item name in the list pane.
    static let listTitle: Font     = .body

    /// Secondary subtitle in the list pane (username, last 4 digits, etc.).
    static let listSubtitle: Font  = .footnote

    /// Status banner text (e.g. "This item is in Trash.") — slightly larger than utility/caption.
    static let bannerText: Font    = .callout

    /// Prominent status label on loading/syncing screens (e.g. "Fetching vault…").
    /// Semibold weight distinguishes it from regular body copy in loading contexts.
    static let progressLabel: Font = .headline

    /// Inline field label shown above a form input (e.g. "Authentication code").
    /// Slightly heavier than `fieldLabel` to visually separate it from body content.
    static let fieldLabelProminent: Font = .callout.weight(.medium)

    /// Top-level sidebar rows (All Items, Favorites, item types, Trash).
    static let sidebarRow: Font = .body

    /// Child sidebar rows (user-created folders).
    static let sidebarChildRow: Font = .body

    /// Large icon on the Login, TOTP, and Unlock screens (keyhole / app symbol).
    static let screenIcon: Font    = .system(size: 48)

    /// Primary heading on the Login, TOTP, and Unlock screens ("Welcome to Prizm").
    static let screenHeading: Font = .title.bold()

    /// Secondary body copy on the Login, TOTP, and Unlock screens.
    static let screenBody: Font    = .callout
}

// MARK: - Spacing
//
// Named spacing tokens for the Prizm Presentation layer.
//
// Prefer these over inline CGFloat literals so that layout rhythm
// stays consistent and tweaks propagate everywhere at once.
enum Spacing {
    /// Horizontal margin at the left and right edges of the detail pane.
    static let pageMargin:    CGFloat = 20

    /// Top padding above the item title / page header.
    static let pageTop:       CGFloat = 28

    /// Bottom padding below the item title before the first section card.
    static let pageHeaderBottom: CGFloat = 12

    /// Vertical padding above a section card (between cards or from the top).
    static let cardTop:       CGFloat = 12

    /// Vertical padding below a section card.
    static let cardBottom:    CGFloat = 18

    /// Gap between a section header label and the card below it.
    static let headerGap:     CGFloat = 8

    /// Vertical padding inside a field row (top and bottom).
    static let rowVertical:   CGFloat = 9

    /// Horizontal padding inside a field row (left and right).
    static let rowHorizontal: CGFloat = 12

    /// Uniform padding inside the item metadata footer (created / updated dates).
    static let footerPadding: CGFloat = 12

    /// Horizontal padding inside status banners (sync error, trash banner).
    static let bannerHorizontal: CGFloat = 12

    /// Horizontal padding for sidebar footer elements (e.g. sync status label).
    /// Matches the visual inset of sidebar section headers.
    static let sidebarHorizontal: CGFloat = 20

    /// Bottom padding for the sidebar sync status label — slightly more than `rowVertical`
    /// to give the footer visual breathing room above the window edge.
    static let sidebarStatusBottom: CGFloat = 14

    /// Vertical padding inside status banners.
    static let bannerVertical: CGFloat = 8

    /// Inner padding for read-only display fields (e.g. the email chip on UnlockView).
    static let readOnlyField: CGFloat = 6

    /// Horizontal padding on full-screen auth/sync flows (Login, TOTP, Unlock, SyncProgress).
    static let screenHorizontal: CGFloat = 40
}
