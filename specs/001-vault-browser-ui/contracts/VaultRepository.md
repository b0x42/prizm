# Contract: VaultRepository

**Layer**: Domain (protocol) — implemented in Data layer
**Purpose**: Read-only access to decrypted vault items (personal ciphers only in v1)

---

## Protocol

```swift
/// Read-only access to the decrypted vault contents.
/// All data is sourced from the in-memory store populated by SyncRepository.sync().
/// v1 is strictly read-only — no mutating methods.
protocol VaultRepository {

    // MARK: - Items

    /// Returns all non-deleted vault items.
    func allItems() async throws -> [VaultItem]

    /// Returns all items matching the given sidebar selection.
    func items(for selection: SidebarSelection) async throws -> [VaultItem]

    /// Returns items matching the search term within the given sidebar selection.
    /// Case-insensitive substring match. Fields matched per type:
    ///   Login:       name, username, uris[].uri, notes
    ///   Card:        name, cardholderName, notes
    ///   Identity:    name, firstName, lastName, email, company, notes
    ///   Secure Note: name, notes
    ///   SSH Key:     name only
    func searchItems(
        query: String,
        in selection: SidebarSelection
    ) async throws -> [VaultItem]

    // MARK: - Item counts (for sidebar badges)

    /// Returns a map from SidebarSelection to item count.
    /// Counts are computed eagerly by VaultRepositoryImpl immediately after sync
    /// populates the in-memory store, and cached internally for the session.
    /// Callers receive the cached result instantly — no recomputation on every call.
    /// Counts do not update mid-session (no background sync in v1).
    func itemCounts() async throws -> [SidebarSelection: Int]

    // MARK: - Detail (full decryption on demand)

    /// Returns the fully decrypted VaultItem for the given id.
    /// The list methods (`items(for:)`, `searchItems`) return list-weight items
    /// sufficient for the item list rows. Call this method when the user selects
    /// an item to populate the detail pane.
    /// Each call re-decrypts from the raw cipher — result is NOT cached. Decryption
    /// of a single cipher via CryptoKit is fast (<1ms) and caching would require
    /// invalidation logic. If this becomes a bottleneck, cache in VaultBrowserViewModel.
    /// Throws `VaultError.itemNotFound` if the id does not exist.
    func itemDetail(id: String) async throws -> VaultItem

    // MARK: - Sync metadata

    /// Timestamp of the last successful vault sync. nil if never synced this session.
    var lastSyncedAt: Date? { get }
}
```

---

## Supporting Notes

- All methods return in-memory data — they are fast and do not perform I/O.
  `async throws` is retained for future extensibility and to satisfy the protocol from a
  Data layer that may bridge to an async SDK call.
- The vault data is populated once during `SyncRepository.sync()` and remains in memory
  for the duration of the unlocked session.
- On lock/sign-out the in-memory store is cleared; all calls after clearing throw
  `VaultError.vaultLocked`.

```swift
enum VaultError: LocalizedError {
    case vaultLocked           // vault not unlocked; call AuthRepository.unlockWithPassword first
    case decryptionFailed      // a cipher could not be decrypted (logged; other items still returned)
    case itemNotFound(String)  // requested item ID does not exist
}
```
