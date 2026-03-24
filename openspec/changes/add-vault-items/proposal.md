## Why

Users can browse and edit existing vault items but cannot create new ones. To save a new login, card, identity, secure note, or SSH key, users must use another Bitwarden client. Adding item creation completes the core CRUD lifecycle and makes Macwarden a self-sufficient vault manager.

## What Changes

- Add a "New Item" button to the vault toolbar that opens a type picker (Login, Card, Identity, Secure Note, SSH Key)
- Reuse the existing edit sheet (`ItemEditView`) for the creation form — same fields, same validation, same save flow
- Add a `POST /api/ciphers` endpoint to `MacwardenAPIClientProtocol`
- Add a `create` method to `VaultRepository` that encrypts a new draft and posts it
- Add a `CreateVaultItemUseCase` domain protocol and implementation
- Extend `DraftVaultItem` with a factory initialiser for blank items of each type
- Insert the server-confirmed item into the in-memory cache after creation (no full re-sync)

## Capabilities

### New Capabilities

- `vault-item-create`: User can create new vault items of all five types (Login, Card, Identity, Secure Note, SSH Key) from the vault browser

### Modified Capabilities

None. The existing edit sheet, draft model, and cipher mapper are reused without spec-level changes.

## Impact

- `MacwardenAPIClientProtocol` / `MacwardenAPIClientImpl` — new `createCipher` method
- `VaultRepository` / `VaultRepositoryImpl` — new `create` method
- `Domain/UseCases/` — new `CreateVaultItemUseCase` protocol + impl
- `DraftVaultItem` — new static factory for blank drafts
- `VaultBrowserView` / `VaultBrowserViewModel` — new toolbar button + type picker
- `ItemEditView` / `ItemEditViewModel` — minor adaptation to support create mode (no existing item)
- `AppContainer` — new factory method for create-mode view model
- `CipherMapper.toRawCipher` — already handles all five types; no changes expected
