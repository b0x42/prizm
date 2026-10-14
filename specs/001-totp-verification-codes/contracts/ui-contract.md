# Contract: User-Facing Surfaces

## Sidebar

- New row "Verification Codes" in the main section, after Favorites. Symbol: a clock-style SF Symbol (choose during implementation, e.g. `clock`). Count badge equals the number of items in the index.
- Accessibility: label "Verification Codes", value is the count; follows the existing `SidebarRowView` conventions. Identifier added to `AccessibilityIdentifiers.swift`.

## List pane (when `.verificationCodes` is selected)

- One row per item, alphabetical by name, filtered by the existing search box (same matching rules as other lists).
- Row content: favicon/type icon (existing component), item name, grouped code (e.g. "123 456"), countdown indicator with seconds, and a copy button.
- Selecting a row opens the item in the detail pane (existing selection binding).
- Copy button copies `TOTPCode.copyValue` (no space) through the existing clipboard path, which clears after 30 s.
- Empty state: "No verification codes" with a short explanation that no items have one. Search with no matches uses the existing no-results presentation.
- Unusable seed: the code area shows "Code unavailable" in place of digits, with no copy button.

## Countdown indicator

- Shows seconds remaining and a progress ring.
- Last 5 seconds: the ring and number change color and weight, and the symbol changes (for example a filled warning style), so the cue is not color alone.

## Detail pane (Login with a usable or unusable seed)

- New card "Verification Code" using `DetailSectionCard`, placed after Credentials. Same row layout as the list row, without the item name.
- No card when the item has no seed.
- The raw seed is never displayed anywhere.

## Menu

- Item > Copy Code (⌃⌘C): copies the current generated code for the selected Login. Disabled when no item is selected, or when the selected item has no usable seed. No other seed-copy command exists.

## Typography and spacing

- Use `Typography.*` and `Spacing.*` tokens only. If no token fits the code text (monospaced digits, larger than `fieldValue`), add one to `DesignSystem.swift` with a comment, per CLAUDE.md.

## Accessibility contract

- Each row is one element: label "Verification code for <name>", value the digits read individually plus "<n> seconds remaining".
- No automatic announcement when a code rotates.
- Section header "Verification Code" carries the `.isHeader` trait.
- Copy button label: "Copy verification code for <name>".
- Countdown uses the `updatesFrequently` trait.

## Lifecycle contract

| Event | Required result |
|---|---|
| Code view appears | Tracking starts; first code shown within 1 s |
| Period ends | New code shown within 1 s |
| Code view disappears | Tracking stops; codes cleared |
| App/window becomes inactive | Tracking stops; codes cleared |
| App/window becomes active again | Tracking resumes with current codes |
| Vault locks | No codes visible; none generated until unlock |
