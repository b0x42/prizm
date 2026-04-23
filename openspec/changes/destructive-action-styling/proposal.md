## Why

Destructive actions (Delete, Empty Trash, Delete Folder, Delete Collection) have inconsistent styling across the app. Some use red text, others don't. The item Delete button lives in the detail toolbar where it can be hit accidentally while browsing — Apple Passwords, 1Password, and other vault apps place it inside the edit sheet instead. Fixing both issues makes destructive actions immediately recognisable and harder to trigger by accident.

## What Changes

- Enforce `.foregroundStyle(.red)` (or `role: .destructive`) on every destructive button and menu item across the app: Delete Item (edit sheet), Delete Permanently, Delete Folder, Delete Collection. "Move to Trash" and the Trash sidebar icon are excluded — trashing is reversible
- Move the item Delete button out of the detail view toolbar and into the bottom of `ItemEditView`
- Keep the existing confirmation alert flow unchanged
- Remove the soft-delete toolbar item from `VaultBrowserView`'s detail toolbar

## Capabilities

### New Capabilities

_None — this is a styling and layout change within existing capabilities._

### Modified Capabilities

- `vault-item-delete`: Delete button moves from detail toolbar to edit sheet; red styling requirement formalised for all delete actions
- `vault-browser-ui`: Detail toolbar no longer contains a Delete button for active items

## Impact

- `Prizm/Presentation/Vault/VaultBrowserView.swift` — remove soft-delete toolbar item and alert from detail toolbar
- `Prizm/Presentation/Vault/Edit/ItemEditView.swift` — add Delete button at bottom of form
- `Prizm/Presentation/Vault/Edit/ItemEditViewModel.swift` — add soft-delete callback
- `Prizm/Presentation/Vault/Sidebar/SidebarView.swift` — verify red styling on Delete Folder / Delete Collection context menu items
- `Prizm/Presentation/Vault/Detail/ItemDetailView.swift` — remove `onSoftDelete` callback (permanent delete for trashed items stays)
- UI tests covering delete flows need updating
