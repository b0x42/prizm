## Context

The detail pane currently renders all vault item fields as a flat `LazyVStack` of `FieldRowView + Divider` rows inside a `ScrollView`. This pattern works for simple items but produces a visually undifferentiated wall of fields for complex types like Identity (17+ fields) or Login (credentials + URIs + notes + custom fields).

The change is confined entirely to the Presentation layer. Domain entities and Data layer are untouched. Existing components (`FieldRowView`, `MaskedFieldView`, `CustomFieldsSection`) are reused as-is.

## Goals / Non-Goals

**Goals:**
- Introduce a `CardBackground` `ViewModifier` (and `.cardBackground()` `View` extension) that applies the card appearance to any view.
- Introduce a `DetailSectionCard` view that combines an optional section header with a `VStack` of field rows wrapped in `.cardBackground()`.
- Refactor all five type-specific detail views (`LoginDetailView`, `CardDetailView`, `IdentityDetailView`, `SecureNoteDetailView`, `SSHKeyDetailView`) to use cards.
- Keep all existing copy-on-hover and masked-field behaviours working identically.

**Non-Goals:**
- Changes to Domain entities, Data layer, or crypto.
- Changing `FieldRowView` internals or its `onCopy` contract.
- Adding new fields or changing which fields are displayed.
- Animations or collapsible sections (deferred).

## Decisions

### 1. `CardBackground` ViewModifier + `DetailSectionCard` wrapper view

**Decision**: Add `Prizm/Presentation/Components/CardBackground.swift` containing:
1. A `CardBackground` `ViewModifier` — applies `.background(Color("CardBackground"))`, `.cornerRadius(20)`, and `.shadow(color: .black.opacity(0.2), radius: 4)`.
2. A `View` extension `.cardBackground()` for ergonomic call sites.
3. A `DetailSectionCard` view that accepts an optional title `String` and a `@ViewBuilder` content closure, rendering a `VStack` of field rows wrapped in `.cardBackground()`.

**Rationale**: The `ViewModifier` approach follows the pattern described at https://danijelavrzan.com/posts/2023/02/card-view-swiftui/ — it keeps card chrome reusable via composition and is idiomatic SwiftUI. `DetailSectionCard` sits on top to handle the optional header without each call site repeating the `VStack`+header pattern.

**Alternatives considered**:
- Standalone `View` struct only — workable, but loses the composability of `.cardBackground()` for one-off uses outside the detail pane.
- `GroupBox` — closer to AppKit conventions but harder to customise corner radius, shadow, and header style.

### 2. `Color("CardBackground")` asset for light/dark mode

**Decision**: Add a `CardBackground` color asset to `Assets.xcassets`: white (`#FFFFFF`) for light mode, dark gray (`#212121`) for dark mode.

**Rationale**: A black shadow on a dark background is invisible, so the card background must shift in dark mode to keep the card visually distinct from the pane background. Named color assets handle this automatically without `@Environment(\.colorScheme)` logic in the modifier.

### 3. Card groupings defined in each detail view, not in Domain

**Decision**: Each detail view (`LoginDetailView`, etc.) owns the mapping from `VaultItem` fields to card sections.

**Rationale**: Field grouping is a purely presentational concern. Encoding it in Domain would violate the architecture rule that Domain imports `Foundation` only and has no UI coupling.

### 4. `CustomFieldsSection` stays as-is

**Decision**: `CustomFieldsSection` is wrapped inside its own `DetailSectionCard("Custom Fields")` when fields are non-empty, rather than refactoring its internals.

**Rationale**: Minimal-change principle — the component already works correctly; only its container changes.

## Risks / Trade-offs

- **Accessibility identifier churn** → UITests that assert on field values by accessibility ID are unaffected (IDs live on `FieldRowView` rows, not the card wrapper). Card headers get their own IDs (e.g. `Detail.cardHeader.credentials`) for future test use but no existing tests need updating.
- **Visual regression** → The flat-list layout is replaced entirely; screenshots in docs/README will go stale. Low risk since there are no screenshot-based tests.
- **Card header text is hardcoded English** → Acceptable for now; localisation is out of scope per project constitution.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| None | This change is confined to the Presentation layer and uses only idiomatic SwiftUI (`ViewModifier`, `@ViewBuilder`, named color assets). No Constitution principles are deviated from. | N/A |

## Migration Plan

Pure in-app refactor — no data migration, no server changes, no API versioning. Deploy by merging to `main`. Rollback is a revert commit.

## Open Questions

- Should empty card sections be hidden entirely (current behaviour for nil fields) or shown as "—"? **Assumed: hide empty sections** (matches current field-level nil-hiding behaviour).
- Should `SecureNoteDetailView` use a single "Note" card or just the existing `FieldRowView` for the note body? **Assumed: single card** for visual consistency.
