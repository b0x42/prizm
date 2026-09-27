import SwiftUI

// MARK: - Colors

enum DesignColor {
    /// Structural separator shared by pane headers and split-view boundaries.
    static let paneDivider = Color.primary.opacity(0.2)

    /// Foreground used on opaque accent-colored selection backgrounds.
    static let selectedContentForeground = Color.white
}

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
    /// Item name in the detail pane - the largest text on screen.
    static let pageTitle: Font     = .largeTitle.bold()

    /// Card section headings ("Credentials", "Websites") - clearly above body text.
    static let sectionHeader: Font = .title3

    /// Primary field content - the value the user cares about.
    static let fieldValue: Font    = .body

    /// Small label rendered above a field value.
    static let fieldLabel: Font    = .subheadline

    /// One character in the large-type field preview.
    static let largeCharacter: Font = .system(size: 48, weight: .medium, design: .monospaced)

    /// One-based position shown below a large-type character.
    static let largeCharacterIndex: Font = .caption.monospacedDigit()

    /// Utility text: COPY button, footer dates, metadata.
    static let utility: Font       = .caption

    /// Seconds remaining in the TOTP countdown badge.
    /// `.monospaced` design (SF Mono) rather than `.monospacedDigit()`: SF Mono has a slashed
    /// zero and tabular glyphs, so "00"→"09" stay legible and the badge width never jitters.
    static let totpCountdown: Font = .system(.caption, design: .monospaced)

    /// Item name in the list pane.
    static let listTitle: Font     = .body

    /// Secondary subtitle in the list pane (username, last 4 digits, etc.).
    static let listSubtitle: Font  = .footnote

    /// Status banner text (e.g. "This item is in Trash.") - slightly larger than utility/caption.
    static let bannerText: Font    = .callout

    /// Prominent status label on loading/syncing screens (e.g. "Fetching vault…").
    /// Semibold weight distinguishes it from regular body copy in loading contexts.
    static let progressLabel: Font = .headline

    /// Inline field label shown above a form input (e.g. "Authentication code").
    /// Slightly heavier than `fieldLabel` to visually separate it from body content.
    static let fieldLabelProminent: Font = .callout.weight(.medium)

    /// Top-level sidebar rows (All Items, Favorites, item types, Trash).
    static let sidebarRow: Font = .system(size: 14, weight: .regular)

    /// Selected vault name in the full-width sidebar context dropdown.
    static let contextDropdownLabel: Font = .title3.weight(.medium)

    /// Leading vault or organization icon in the sidebar context dropdown.
    /// Sized to sit inside a ~20pt tinted square, matching Finder-style sidebar glyphs.
    static let contextDropdownIcon: Font = .system(size: 12, weight: .semibold)

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

    /// Vertical gap between a field label and its value.
    static let fieldContentGap: CGFloat = 3

    /// Gap between trailing field actions.
    static let fieldActionGap: CGFloat = 6

    /// Gap between a TOTP digit group and its middle-dot separator.
    /// Tighter than a monospaced space cell so the dot reads as part of the code.
    static let totpGroupGap: CGFloat = 4

    /// Gap between the TOTP countdown ring and its seconds label inside the badge.
    static let totpRingGap: CGFloat = 5

    /// Vertical inner padding of the TOTP countdown badge.
    /// Taller than `badgeVertical` so the ring has breathing room above and below its stroke.
    static let totpBadgeVertical: CGFloat = 3

    /// Padding inside transient copy confirmation capsules.
    static let toastHorizontal: CGFloat = 10

    /// Vertical padding inside transient copy confirmation capsules.
    static let toastVertical: CGFloat = 6

    /// Gap between characters in the large-type preview.
    static let largeCharacterGap: CGFloat = 16

    /// Uniform padding inside the item metadata footer (created / updated dates).
    static let footerPadding: CGFloat = 12

    /// Horizontal padding inside status banners (sync error, trash banner).
    static let bannerHorizontal: CGFloat = 12

    /// Horizontal padding for sidebar footer elements (e.g. sync status label).
    /// Matches the visual inset of sidebar section headers.
    static let sidebarHorizontal: CGFloat = 20

    /// Bottom padding for the sidebar sync status label - slightly more than `rowVertical`
    /// to give the footer visual breathing room above the window edge.
    static let sidebarStatusBottom: CGFloat = 14

    /// Space between the vault context picker and the sidebar divider.
    static let sidebarContextBottom: CGFloat = 20

    /// Space above the vault context picker. Kept small because the hidden title bar
    /// already reserves the traffic-light strip above the sidebar content.
    static let sidebarContextTop: CGFloat = 8

    /// Horizontal padding inside the vault context picker. Kept tight so the selected
    /// vault name has as much room as possible in a narrow sidebar.
    static let contextPickerHorizontal: CGFloat = 8

    /// Outer horizontal inset of the vault context picker within the sidebar.
    /// Narrower than `sidebarHorizontal` so the picker spans most of the sidebar width.
    static let contextPickerOuterHorizontal: CGFloat = 10

    /// Inner padding around the glyph inside the tinted icon square of the context picker.
    static let contextPickerIconPadding: CGFloat = 4

    /// Vertical padding inside status banners.
    static let bannerVertical: CGFloat = 8

    /// Inner padding for read-only display fields (e.g. the email chip on UnlockView).
    static let readOnlyField: CGFloat = 6

    /// Horizontal inner padding for inline badge labels (e.g. org membership badge on item rows).
    static let badgeHorizontal: CGFloat = 5

    /// Vertical inner padding for inline badge labels.
    static let badgeVertical: CGFloat = 1

    /// Corner radius for inline badge labels.
    static let badgeCornerRadius: CGFloat = 4

    /// Corner radius for the full-width vault context picker.
    static let contextPickerCornerRadius: CGFloat = 8

    /// Corner radius for square item icons in list and detail views.
    static let itemIconCornerRadius: CGFloat = 6

    /// Outer horizontal breathing room around active and hovered item backgrounds.
    static let itemHighlightHorizontalMargin: CGFloat = 6

    /// Horizontal padding on full-screen auth/sync flows (Login, TOTP, Unlock, SyncProgress).
    static let screenHorizontal: CGFloat = 40

    /// Inner padding for searchable select triggers and result rows.
    static let searchableSelectPadding: CGFloat = 8

    /// Gap between the searchable select icon, label, and trailing controls.
    static let searchableSelectGap: CGFloat = 7

    /// Breathing room between searchable select content and popover edges.
    static let searchableSelectPopoverPadding: CGFloat = 12
}

// MARK: - Layout Metrics

enum LayoutMetrics {
    /// Shared height for the list filter bar and detail action bar.
    static let paneActionBarHeight: CGFloat = 44

    /// Compact countdown ring displayed beside a one-time password.
    /// Sized to match the cap height of `Typography.utility` so it sits inline with the seconds.
    static let totpProgressDiameter: CGFloat = 12

    /// Stroke width of the TOTP countdown ring.
    static let totpProgressLineWidth: CGFloat = 2

    /// Height of text inputs on full-screen authentication flows.
    static let authenticationInputHeight: CGFloat = 36

    /// Width of forms on full-screen authentication flows.
    static let authenticationFormWidth: CGFloat = 440

    /// Width of the searchable select popover.
    static let searchableSelectWidth: CGFloat = 380

    /// Maximum height of the searchable select results list.
    static let searchableSelectResultsHeight: CGFloat = 240
}
