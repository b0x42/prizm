## Why

Login vault items store one or more website URIs that serve two purposes: letting the user jump to a site to log in, and enabling Bitwarden browser extensions to match and prefill credentials. Currently the edit form only allows modifying existing URI text and match type — users cannot add new URIs, remove stale ones, or reorder them. Since Bitwarden treats the first URI as the primary match target, the inability to reorder also affects autofill behavior.

## What Changes

- Add an "Add Website" button to the Login edit form that appends a blank URI row
- Add an inline remove button (−) on each URI row to delete it
- Add ▲▼ reorder buttons on each URI row to move it up/down in the list
- Always show the Websites section in the edit form (even when no URIs exist yet)
- Add an empty initializer to `DraftLoginURI` so blank rows can be created
- Hide match type picker behind a gear icon toggle with animated reveal
- Add `Identifiable` conformance to `DraftLoginURI` for stable SwiftUI ForEach identity

## Capabilities

### New Capabilities
- `uri-add-remove-reorder`: Add, remove, and reorder website URIs on Login vault items in the edit form

### Modified Capabilities

## Impact

- `Macwarden/Domain/Entities/DraftVaultItem.swift` — new initializer on `DraftLoginURI`, remove v1 scope comment
- `Macwarden/Presentation/Vault/Edit/LoginEditForm.swift` — add/remove/reorder UI controls in the Websites section
- No API changes needed — the Bitwarden API accepts the full `uris` array on save (full replacement)
- No mapper changes — `CipherMapper` already handles variable-length URI arrays
