## Context

Prizm's vault browser (001-vault-browser-ui) is read-only. All domain entities (`VaultItem`, `LoginContent`, etc.) are immutable value types (`let` fields). The Data layer already handles decryption via `PrizmCryptoService` and communicates with the Bitwarden/Vaultwarden REST API via `PrizmAPIClient`. There is no existing write path (no PUT/POST cipher calls).

The Bitwarden API cipher update endpoint (`PUT /ciphers/{id}`) accepts a JSON body with re-encrypted field values in `EncString` format — the same format already used for decryption. The existing `CipherMapper` translates `RawCipher` → `VaultItem` (read direction only).

## Goals / Non-Goals

**Goals:**
- Allow users to edit any field on any of the five item types (Login, Card, Identity, Secure Note, SSH Key).
- Persist edits by calling `PUT /ciphers/{id}` and updating the in-memory vault cache on success.
- Keep the edit UI consistent with the existing detail card layout (same design tokens, same field components where possible).
- Full test coverage on the reverse mapper and the update use case.
- Keyboard shortcuts: `⌘E` opens the edit sheet for the selected item, `⌘S` saves, `Esc` discards and dismisses.
- macOS menu bar extra labelled "Item" with a dropdown containing Edit and Save actions, visible while the vault is unlocked.

**Non-Goals:**
- Creating new vault items (add/create flow is a separate change).
- Deleting items.
- Changing item type (e.g., Login → Secure Note).
- **Adding or removing URIs** — existing URIs are editable but the list is fixed.
- **Adding, removing, or reordering custom fields** — existing custom fields are editable but the list is fixed.
- Editing password history or attachments.
- Offline editing / conflict resolution.
- Biometric re-authentication before save (deferred — no entitlement yet).

## Decisions

### 1. `DraftVaultItem` mutable mirror instead of mutating `VaultItem`

`VaultItem` and its content types are `struct`s with `let` fields, enabling safe sharing across the Presentation and Domain layers. Rather than change them to `var` (which would widen mutation surface everywhere), we introduce `DraftVaultItem` — a parallel mutable struct with `var` fields, used only inside the edit form.

**Alternative considered**: Make `VaultItem` fields `var`. Rejected because it removes the accidental-mutation safety guarantee and would require `@State` copies throughout the read-only detail views.

**Conversion**: `DraftVaultItem.init(_ item: VaultItem)` (domain → draft) and `VaultItem.init(_ draft: DraftVaultItem)` (draft → domain, after successful save) keep the boundary clean.

### 2. Reverse mapper in `CipherMapper` (domain → wire)

The `CipherMapper` already owns the read-direction mapping. Adding a `toRawCipher(_ draft: DraftVaultItem, encryptedWith key: SymmetricKey) throws -> RawCipher` method in the same file keeps all wire-format knowledge co-located.

**Alternative considered**: A separate `CipherSerializer`. Rejected — the mapper already owns the bidirectional knowledge; splitting it adds indirection with no benefit.

### 3. Single `ItemEditView` with per-type sub-forms

`ItemDetailView` already switches on `item.content` to dispatch to per-type views. The edit layer follows the same pattern: `ItemEditView` owns the sheet container, toolbar, and save/cancel actions; per-type sub-forms (`LoginEditForm`, `CardEditForm`, etc.) own their field layout.

`ItemEditViewModel` holds the `@Published var draft: DraftVaultItem` and owns the async save call, matching the `ItemDetailView`/`VaultBrowserViewModel` pattern already established.

### 4. Sheet presentation, not navigation push

Edits are presented as a `.sheet` from the detail pane. This keeps the read-only detail visible underneath (cancellable, no nav stack pollution) and matches platform convention for modal editing on macOS.

### 5. Inline error, sheet stays open on failure

On save failure the sheet remains open and shows an error banner. Dismissing on failure would lose unsaved edits, which is a worse UX than an inline error.

### 6. Keyboard shortcuts via SwiftUI `.keyboardShortcut`

`⌘E` is attached to the Edit button in `ItemDetailView` using `.keyboardShortcut("e", modifiers: .command)`. It fires only when an item is selected (button is enabled).

`⌘S` is attached to the Save button in `ItemEditView` using `.keyboardShortcut("s", modifiers: .command)`. It fires only when the sheet is open and the form is valid.

`Esc` is handled by SwiftUI's built-in sheet dismissal combined with a `onExitCommand` modifier on the sheet content, which calls the same discard-with-confirmation logic as the Cancel button.

**Alternative considered**: Global `NSEvent` monitor. Rejected — SwiftUI `.keyboardShortcut` and `onExitCommand` are sufficient, require no AppKit interop, and respect focus automatically.

### 7. macOS menu bar extra via `MenuBarExtra`

A `MenuBarExtra` labelled `"Item"` (SwiftUI, macOS 13+) is added to the app's `@main` scene with `.menuBarExtraStyle(.menu)`. Its dropdown contains two `Button` entries:

- **Edit** — triggers the same action as ⌘E (opens the edit sheet for the selected item); disabled when no item is selected or the vault is locked. `.keyboardShortcut("e", modifiers: .command)` causes macOS to render `⌘E` inline in the dropdown automatically.
- **Save** — triggers the same action as ⌘S (saves in-flight edits); disabled when no edit sheet is open or a save is already in progress. `.keyboardShortcut("s", modifiers: .command)` renders `⌘S` inline.

The extra is conditionally present only when the vault is unlocked, controlled by `MenuBarViewModel` which observes shared session state.

**Alternative considered**: `NSStatusBar` + `NSStatusItem` via AppKit. Rejected — `MenuBarExtra` is the SwiftUI-native approach on macOS 13+, requires no AppKit interop, and the `.menu` style produces a native dropdown without extra plumbing.

### 8. In-memory cache update on success (no full re-sync)

After a successful PUT, `VaultRepositoryImpl` replaces the item in the in-memory item list with the updated `VaultItem`. A full re-sync would be slower and flash the list. The server response to PUT /ciphers/{id} returns the updated raw cipher, which is mapped back to `VaultItem` and spliced into the cache.

**Risk**: If the server applies server-side changes (e.g., auto-increment revision date) they are captured because we map the response body — not the draft — back into the cache.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Re-encryption bug silently corrupts a vault item | Unit test the reverse mapper round-trip (encrypt → decrypt → compare) against known Bitwarden test vectors |
| Edit sheet state lost on app backgrounding | Acceptable for v1 — `DraftVaultItem` is in-memory only; add persistence in a future change if needed |
| PUT API shape differs between Bitwarden cloud and self-hosted Vaultwarden | Existing sync already targets both; same `PrizmAPIClient` pattern applies. Test against Vaultwarden locally. |
| Large identity forms are verbose on macOS | Use the same card-section layout as detail views; group fields into collapsible sections if user feedback warrants |
| Custom field reordering UX on macOS | Use `List` with `.onMove` — native macOS drag-to-reorder, same approach used in system apps |

## Open Questions

- Should saving an item also update the `revisionDate` field locally, or rely entirely on the server response? → Rely on server response (safe default).
- Should we show a "dirty" indicator (e.g., modified title in toolbar) when the user has unsaved edits? → Nice to have; defer to v2.
- URI match-type picker: include all six `URIMatchType` cases in the edit form, or just the four common ones? → All six for completeness; they map 1:1 to the enum.
