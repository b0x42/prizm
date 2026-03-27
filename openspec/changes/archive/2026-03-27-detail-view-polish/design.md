## Context

`CardBackground` currently applies `Color("CardBackground")`, `cornerRadius(12)`, and `shadow(color: .black.opacity(0.15), radius: 3, y: 1)`. `FieldRowView` uses a stacked layout: label on top (`.subheadline`, `.secondary`), value below (`.body`).

macOS System Settings and Apple's Passwords app use shadowless cards with horizontal label/value rows. This change aligns with that pattern.

## Goals / Non-Goals

**Goals:**
- Remove card shadow
- Reduce corner radius to 10pt
- Horizontal label/value layout for single-line fields
- Stacked layout preserved for multi-line content (notes)

**Non-Goals:**
- Changing card background colors
- Changing typography tokens
- Changing spacing tokens
- Centered item headers (deferred)

## Decisions

### Decision 1: Remove shadow entirely rather than reducing it

**Chosen:** Remove the `.shadow()` modifier from `CardBackground`.

**Rationale:** macOS System Settings uses zero shadow on grouped cards. The background color contrast between card and pane is sufficient. Removing the shadow simplifies the modifier and matches the platform convention.

### Decision 2: Detect multi-line content by field label

**Chosen:** `FieldRowView` uses horizontal layout by default. A new `isMultiLine` parameter (defaulting to `false`) switches to stacked layout. Callers pass `isMultiLine: true` for notes fields.

**Rationale:** Simpler than auto-detecting line count. The caller knows whether the field is a notes/freeform field. Keeps `FieldRowView` stateless.

## Risks / Trade-offs

- Long values (emails, URIs) may truncate in horizontal layout. Mitigated by `.lineLimit(1)` with truncation on values, which is already the behavior users expect for scannable rows. Notes and freeform fields use stacked layout to avoid this.
- Existing UI tests reference field layout by accessibility identifiers, not visual position — no test breakage expected.
