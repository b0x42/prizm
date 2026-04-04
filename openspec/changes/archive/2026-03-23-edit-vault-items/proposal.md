## Why

The vault browser is currently read-only. Users who spot an error in a saved item — a changed password, a wrong URL, a misspelled name — have no way to correct it inside Prizm, forcing them to use the Bitwarden web vault instead. Editing is a core vault management capability and the most-requested missing feature after read support.

## What Changes

- An **Edit button** is added to every item detail pane, opening an edit sheet/form for the selected item.
- Edit forms are provided for all five item types: **Login, Card, Identity, Secure Note, SSH Key**.
- Existing custom fields can be edited within the edit form (adding, removing, and reordering is out of scope).
- Existing Login URIs can be edited within the edit form (adding and removing is out of scope).
- Saving triggers a **PUT /ciphers/{id}** call to the Bitwarden/Vaultwarden API, re-encrypting the item with the current vault key before transmission.
- On success, the in-memory vault cache is updated and the detail pane refreshes.
- On failure, an inline error is shown and the edit sheet remains open.
- The item `name` (displayed in the list pane) is always editable regardless of item type.
- A **macOS menu bar extra** labelled "Item" is added with a dropdown menu containing **Edit** (⌘E) and **Save** (⌘S) actions that operate on the currently selected vault item.
- **Keyboard shortcuts**: `⌘E` opens the edit sheet for the selected item; `⌘S` saves changes; `Esc` discards changes and dismisses the edit sheet.

## Capabilities

### New Capabilities

- `vault-item-edit`: Edit form UI (SwiftUI sheet) and save flow for all five vault item types, covering field editing, URI/custom-field management, re-encryption, API PUT, and local cache update. Includes keyboard shortcuts (⌘E to open, ⌘S to save, Esc to discard) and a macOS menu bar extra ("Item") with Edit and Save actions.

### Modified Capabilities

- `detail-card-view`: The read-only detail pane gains an "Edit" toolbar button that triggers the edit sheet. No requirement changes to card rendering itself.

## Impact

- **Domain**: New `EditVaultItemUseCase` protocol + `VaultItem` must be mutable (introduce a `DraftVaultItem` value type mirroring `VaultItem` with `var` fields for editing).
- **Data**: `VaultRepository` protocol gains `update(_ item: DraftVaultItem) async throws`. `VaultRepositoryImpl` implements the PUT call + re-encryption. `CipherMapper` gains a reverse mapper (domain → `RawCipher` wire format).
- **Presentation**: New `ItemEditView` + per-type edit sub-views + `ItemEditViewModel`. `ItemDetailView` gains a toolbar Edit button. A `MenuBarExtra` ("Item") exposes Edit and Save actions. Keyboard shortcuts wired via `.keyboardShortcut`.
- **Tests**: Unit tests for `EditVaultItemUseCase`, `CipherMapper` reverse mapper, and `VaultRepositoryImpl` update path. UI journey test for the edit-and-save flow.
- **No new dependencies** — editing uses the same `PrizmAPIClient` and `PrizmCryptoService` already in the Data layer.
