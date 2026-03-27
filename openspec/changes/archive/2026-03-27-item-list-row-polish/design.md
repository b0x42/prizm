## Context

`ItemRowView` currently uses `.padding(.vertical, 2)`, `Typography.listTitle` (`.body`, 13pt) for the name, and `Typography.listSubtitle` (`.caption`, 10pt) for the subtitle. Spacing between name and subtitle is 1pt. The rows feel tight compared to the detail pane's generous card layout.

## Goals / Non-Goals

**Goals:**
- Taller rows with more vertical padding
- More spacing between name and subtitle
- Item name uses `.headline` (13pt semibold) to match detail view section headers

**Non-Goals:**
- Changing favicon size or spacing
- Changing subtitle content or logic
- Changing list selection behavior

## Decisions

### Decision 1: Use `.headline` for item name

**Chosen:** Item name uses `.headline` font, matching the detail view section headers ("Credentials", "Websites").

**Rationale:** Creates visual consistency between the list and detail panes. The semibold weight makes item names easier to scan in a long list.

### Decision 2: Increase vertical padding to 8pt

**Chosen:** `.padding(.vertical, 8)` on the row, spacing between name and subtitle increased to 3pt.

**Rationale:** Gives each row breathing room without making the list feel wasteful. Comparable to Apple's Passwords app list density.

## Risks / Trade-offs

- Taller rows mean fewer visible items without scrolling. Acceptable — scannability matters more than density for a password manager.
