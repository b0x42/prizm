## Context

The Login edit form (`LoginEditForm`) uses a `ScrollView` > `VStack` > `DetailSectionCard` layout with custom `EditFieldRow` components. URI rows are rendered via `ForEach(draft.uris.indices)` with a `URIEditRow` that binds to each `DraftLoginURI`. The Websites section is conditionally shown only when `draft.uris` is non-empty.

`DraftLoginURI` is a mutable mirror of the immutable `LoginURI` domain entity. It currently only has an `init(_ source: LoginURI)` initializer — no way to create a blank instance.

The Bitwarden API accepts the full `uris` array on cipher update (full replacement), so adding/removing URIs requires no API-level changes. The `CipherMapper` already maps variable-length URI arrays in both directions.

## Goals / Non-Goals

**Goals:**
- Users can add new website URIs to a Login item
- Users can remove existing URIs from a Login item
- Users can reorder URIs (important because Bitwarden treats the first URI as the primary autofill match)
- The Websites section is always visible in the edit form, even with zero URIs

**Non-Goals:**
- URI validation (Bitwarden itself accepts bare domains, IPs, etc.)
- Migrating edit forms from card layout to native `Form` — keep existing `DetailSectionCard` pattern
- Add/remove for custom fields (separate change)
- Drag-to-reorder (using ▲▼ buttons instead for layout consistency)

## Decisions

**Decision 1: ▲▼ buttons for reordering instead of drag-to-reorder**

The edit forms use `ScrollView` > `VStack` > `DetailSectionCard`. SwiftUI's native `onMove` requires `List`/`ForEach`, which would clash with the card-based styling. ▲▼ buttons keep the existing layout intact and are keyboard-accessible.

Alternative considered: Migrating to `Form` + `onMove`. Rejected because it would require restyling all five edit forms for visual consistency — too large a scope for this change.

**Decision 2: Inline remove button per row**

Each URI row gets a [−] button. This matches Option A from exploration (inline controls) and is the most discoverable pattern within the card layout.

**Decision 3: Memberwise initializer on DraftLoginURI**

Add `init(uri: String = "", matchType: URIMatchType? = nil)` so blank URIs can be created for the "Add Website" action. The existing `init(_ source: LoginURI)` remains unchanged.

**Decision 4: Always show Websites section**

Remove the `if !draft.uris.isEmpty` guard so the section always renders. When empty, it shows only the "Add Website" button.

## Risks / Trade-offs

**[Risk] Accidental removal with no undo** → The edit sheet already has a Cancel button that discards all changes. Removing a URI is not persisted until Save. This is sufficient protection.

**[Risk] ▲▼ buttons add visual noise to each row** → Buttons are disabled at boundaries (▲ on first, ▼ on last) and hidden when only one URI exists, reducing clutter.
