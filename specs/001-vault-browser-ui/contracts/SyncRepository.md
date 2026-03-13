# Contract: SyncRepository

**Layer**: Domain (protocol) — implemented in Data layer
**Purpose**: Fetching and decrypting the vault from the Bitwarden server

---

## Protocol

```swift
/// Handles vault sync: fetching encrypted vault JSON from the server and passing it
/// to the SDK for decryption. Called exactly once per session (on login or unlock).
protocol SyncRepository {

    /// Fetches the encrypted vault from the server, decrypts it via the SDK,
    /// and populates the VaultRepository's in-memory store.
    ///
    /// Progress is reported via the `onProgress` callback with human-readable
    /// status messages (e.g. "Syncing vault…", "Decrypting…").
    ///
    /// On failure, throws a `SyncError` and does NOT partially populate the store.
    func sync(
        onProgress: @escaping (String) -> Void
    ) async throws -> SyncResult
}
```

---

## Supporting Types

```swift
struct SyncResult {
    let syncedAt: Date
    let totalCiphers: Int
    let failedDecryptionCount: Int   // ciphers that could not be decrypted (logged, not fatal)
}

enum SyncError: LocalizedError {
    case networkUnavailable
    case serverUnreachable(URL)
    case unauthorized            // access token expired and refresh failed
    case decryptionFailed        // catastrophic failure; individual cipher errors are non-fatal
    case syncInProgress          // sync already running; caller should await existing sync
}
```

---

## Behaviour Notes

- `sync()` is called from a `SyncUseCase` in the Domain layer, triggered by:
  1. Successful login (`AuthRepository.loginWithPassword` / `loginWithTOTP`)
  2. Successful unlock (`AuthRepository.unlockWithPassword`)
- There is **no background sync, periodic poll, or user-triggered re-sync** in v1 (FR-037).
- The progress callback fires at minimum two status messages: `"Syncing vault…"` (before the
  network call) and `"Decrypting…"` (before the SDK decryption step).
- If any individual cipher fails to decrypt, it is skipped and the error is logged; the rest of
  the vault is still returned (FR-033 graceful handling).
- `lastSyncedAt` on `VaultRepository` is updated to `SyncResult.syncedAt` on success.
- **Concurrent calls**: if `sync()` is called while a sync is already in progress, the second
  caller receives `SyncError.syncInProgress`. In v1 there is only one call site (the post-login/
  unlock `SyncUseCase`), so this error will not occur in practice. Callers MUST NOT retry on
  receiving this error; they SHOULD ignore it.
- **Stale data after failure**: if `sync()` fails mid-session (FR-049), previously decrypted
  items remain in the `VaultRepository` in-memory store unchanged and continue to be displayed.
  No per-item staleness flag is surfaced in v1.
