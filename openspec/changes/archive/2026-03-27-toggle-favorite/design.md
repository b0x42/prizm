## Context

`VaultItem.isFavorite` is read-only. `DraftVaultItem.isFavorite` is mutable and sent to the server via `CipherMapper.toRawCipher()`. `VaultRepository.update(_:)` re-encrypts and PUTs the cipher. The Favorites sidebar filter already works — only the toggle trigger is missing, and the star indicator moves from list rows to the detail toolbar.

## Goals / Non-Goals

**Goals:**
- Toggle favorite from the detail view toolbar (star icon button)
- Toggle favorite from the list row context menu
- Remove star indicator from list rows (moved to detail toolbar)
- Immediate UI update (optimistic: update local cache, sync to server)

**Non-Goals:**
- Bulk favorite/unfavorite
- Favorite toggle via keyboard shortcut (can be added later)
- Favorite toggle in the edit sheet (already possible by editing the draft, but not discoverable)

## Decisions

### Decision 1: Toggle via `VaultBrowserViewModel`, not a new use case

**Chosen:** `VaultBrowserViewModel.toggleFavorite(item:)` creates a `DraftVaultItem` with flipped `isFavorite`, calls `VaultRepository.update()`, and refreshes the list.

**Rationale:** This follows the same pattern as the existing edit flow. A dedicated `ToggleFavoriteUseCase` would add indirection for a single-field update. The existing `EditVaultItemUseCase` / `VaultRepository.update()` handles it.

**Constitution §II note:** `VaultBrowserViewModel` calling `VaultRepository.update()` directly is consistent with how delete/restore already work in the same VM.

### Decision 2: Star button in detail toolbar, not inside the card

**Chosen:** A star toggle button in the detail view toolbar (next to Edit/Delete).

**Rationale:** Toolbar placement is discoverable and consistent with Edit/Delete. Putting it inside a card would require deciding which card it belongs to.

## Risks / Trade-offs

- **Optimistic update:** The local cache updates immediately, but if the server request fails, the UI will be out of sync until the next full sync. Acceptable for v1 — same risk as edit/delete.
