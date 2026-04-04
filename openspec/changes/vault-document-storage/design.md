## Context

Prizm already stores five vault item types with end-to-end encryption using Bitwarden's AES-256-CBC + HMAC-SHA256 EncString scheme, backed by `PrizmCryptoService`. The Bitwarden/Vaultwarden server provides a first-class Attachments API: file data is encrypted client-side, uploaded to the server (via a signed URL), and returned as part of the vault sync. Vaultwarden stores attachment files on disk or in S3-compatible storage; Bitwarden cloud requires a premium account.

An earlier draft of this design proposed local-only encrypted file storage in the app container. That approach was rejected because it cannot sync across devices and diverges from the Bitwarden standard, which would require a full rewrite to add sync later. The standard API is the right foundation.

## Goals / Non-Goals

**Goals:**
- Implement file attachments using the Bitwarden Attachments API (`POST /api/ciphers/{id}/attachment`, `DELETE /api/ciphers/{id}/attachment/{attachmentId}`)
- Implement two-layer client-side encryption per the Bitwarden security whitepaper: per-attachment key encrypts file data; cipher key encrypts the attachment key
- Surface attachments in the vault item detail pane (list, open, save to disk, delete, add)
- Attachments sync automatically as part of the existing `GET /api/sync` flow
- Enforce a 500 MB per-file size limit (matching the Bitwarden server limit) in the UI before any upload

**Non-Goals:**
- Local-only attachment storage (rejected — no sync, non-standard)
- Attachment editing or in-app preview/rendering
- Attachment search or filtering
- Organisation-level attachment quotas or billing UI
- Sends (file sharing) — separate feature

## Decisions

### 1. Per-attachment encryption — two-layer key scheme, three encrypted artifacts

**Decision:** For each attachment:
1. Generate a random 64-byte `attachmentKey` (32-byte enc key ‖ 32-byte mac key)
2. Encrypt file data with `attachmentKey` using AES-256-CBC + HMAC-SHA256 → `encryptedData`
3. Encrypt `attachmentKey` with the cipher's own symmetric key (or the user's vault key if the cipher has no per-item key) → `encryptedAttachmentKey` (EncString type 2)
4. Encrypt `fileName` with the cipher's symmetric key → `encryptedFileName` (EncString type 2); this prevents the server from learning the original file name
5. Upload `encryptedAttachmentKey` and `encryptedFileName` as metadata; upload `encryptedData` as the file blob

This produces three encrypted artifacts per attachment: the file data, the attachment key, and the file name. All three use the same AES-256-CBC + HMAC-SHA256 scheme. The file name uses the cipher key directly (not the attachment key) because the attachment key is generated fresh per upload and is not available at sync time when the file name must be decryptable from metadata alone.

**Why this scheme:** This is the documented Bitwarden attachment crypto. It means each attachment has an independent key — compromising one attachment key does not expose any other attachment or vault item. It also matches what the server expects.

**Alternatives considered:**
- *Re-use cipher's vault key directly to encrypt file data* — simpler, but non-standard; server rejects metadata format and any future official Bitwarden client would fail to decrypt
- *Streaming encryption* — not needed for ≤500 MB with macOS memory; adds complexity for no current benefit

### 2. Signed-URL upload pattern

**Decision:** Follow the two-step v2 upload flow:
1. `POST /api/ciphers/{id}/attachment/v2` with JSON metadata (`fileName` = `encryptedFileName`, `key` = `encryptedAttachmentKey`, `fileSize` = plaintext byte count) → server returns `{ attachmentId, url, fileUploadType }` where `url` is a signed upload URL
2. For `fileUploadType` = `1` (Azure): `PUT <signed-url>` with the raw encrypted blob as the request body and header `x-ms-blob-type: BlockBlob`. For `fileUploadType` = `0` (Vaultwarden direct): `POST /api/ciphers/{id}/attachment/{attachmentId}` with the encrypted blob as multipart form field `data`.

**Why:** This is the server's required flow. Attempting to send the file directly in the POST would violate the API contract.

**Vaultwarden note:** Vaultwarden supports `fileUploadType` = `0` (direct) where the signed URL points back to `POST /api/ciphers/{id}/attachment/{attachmentId}`. Handle both `0` (direct) and `1` (Azure blob) upload types.

### 3. Download on demand, not prefetch

**Decision:** Attachment file data is NOT downloaded during vault sync. Only attachment metadata (id, fileName, size, `encryptedAttachmentKey`) is stored in the in-memory vault cache. The file is fetched and decrypted only when the user explicitly clicks Open or Save to Disk.

**Why:** Attachments can be up to 500 MB each; prefetching all attachments on sync would be impractical and wasteful. Metadata is lightweight and sufficient for the list view.

### 4. No local caching of decrypted attachment data

**Decision:** Decrypted file data is NEVER written to a persistent store. For "Open", write the plaintext to a `FileManager` temp directory, open with `NSWorkspace`, then overwrite with zeroes and delete after 30 seconds. For "Save to Disk", write directly to the user-chosen path and zero the in-memory buffer immediately after.

**Why:** Prizm is a security app. Leaving decrypted files on disk — even in a temp directory — is a data exposure risk that the temp-file lifecycle mitigates.

**30-second rationale:** 30 seconds is the minimum time judged sufficient for the target application (e.g. Preview, Acrobat) to open and read the file after `NSWorkspace.shared.open` returns. It is not a security deadline — once the app has the file handle, the data is in that process's memory regardless. The 30-second window simply avoids deleting the file before the target app has finished reading it.

**Timer suspension risk:** macOS may suspend background `Task` timers when the app moves to the background immediately after Open. As a safety net, `AttachmentTempFileManager` (App layer — imports `NSApplication`) registers for `NSApplication.didBecomeActiveNotification` and sweeps any temp files whose scheduled deletion time has passed. This ensures cleanup occurs on the next app foreground even if the timer fired while suspended. Placed in `App/` rather than Data layer because it requires AppKit (§II).

### 5. 500 MB UI limit enforced before upload

**Decision:** Reject files larger than 500 MB (524 288 000 bytes) at the file picker stage, before reading file content into memory. Show a clear error. This matches the Bitwarden server limit.

### 6. Cipher key resolution — separate Data layer cache, not stored in VaultItem

**Decision:** The effective cipher symmetric key (per-item key if present, vault key otherwise) is NOT stored in the `VaultItem` Domain entity. Instead, `VaultKeyServiceImpl` (Data layer) maintains a separate `[String: Data]` cache (cipher ID → effective key), populated during sync alongside the vault and cleared on lock.

**Why:** The Constitution (§III) requires minimizing unencrypted key material in memory and keeping all crypto concerns in the Data layer. Storing a symmetric key in every `VaultItem` would:
1. Add key material to Domain entities (violates §II — Domain should be crypto-free)
2. Expand the key material footprint unnecessarily (violates §III)

The current code discards the per-item cipher key after `CipherMapper.map(raw:keys:)` returns. `VaultKeyServiceImpl` restores access to that key via a parallel cache with the same lifecycle as the vault.

**Data flow:**
```
SyncRepositoryImpl
  → CipherMapper produces (VaultItem, effectiveCipherKey: Data) per cipher
  → VaultRepository.populate(items:)      ← unchanged
  → VaultKeyCache.populate(keys:)         ← new, [cipherId: Data]
  → both cleared together on vault lock

VaultKeyServiceImpl (Data layer)
  → conforms to Domain VaultKeyService protocol
  → reads from VaultKeyCache for the cipher's key
  → falls back to crypto.currentKeys().symmetricKey when nil (cipher has no per-item key)
  → throws VaultError.vaultLocked when cache is empty (vault is locked)
```

**Alternatives considered:**
- *Store key in `VaultItem`* — rejected: adds crypto material to Domain entities, violates §II and §III
- *Re-fetch raw cipher from API on demand* — rejected: network call on every attachment operation, violates §VI (unnecessary complexity)
- *Always use vault key, ignore per-item key* — rejected: incorrect for ciphers with their own key; Bitwarden clients that wrote a per-item key would produce attachments that Prizm cannot decrypt

### 7. Premium gate surfaced in UI, not enforced by the app

**Decision:** Prizm does not check the user's Bitwarden premium status before showing the Add Attachment button. If the server rejects the upload (402 or error body indicating premium required), the app surfaces the server's error message inline. Vaultwarden users are unaffected.

**Rationale:** Proactively gating the feature requires an extra API call (profile fetch) and maintenance burden as Bitwarden changes its plan tiers. The server is the authoritative source; reflecting its error is sufficient.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Upload interrupted mid-way — server has metadata but no file | On next sync, detect attachments with metadata but no resolvable download URL; show "upload incomplete" state and offer retry/delete |
| Decrypted plaintext in memory during encrypt/decrypt of large file (up to 500 MB) | Load fully into memory; the 500 MB hard limit combined with macOS memory management makes streaming unnecessary for v1. Streaming is deferred (see Alternatives Considered in §1). |
| `attachmentKey` zeroisation — Swift `Data` is CoW and may be copied | Use `withUnsafeMutableBytes` to zero in place; avoid passing `Data` containing key material across actor boundaries |
| Bitwarden cloud rejects upload with 402 (premium required) | Catch HTTP 402, show localised "Attachments require a Bitwarden Premium account" message |
| Signed upload URL expiry during slow upload | Re-request a new signed URL and retry once on 403 from the upload endpoint |

## Complexity Tracking

Per §I of the Constitution, AppKit usage must be documented and justified here. Per §VI (YAGNI), non-obvious feature additions must also be justified against a simpler alternative.

### AppKit Usage

| AppKit API | Used in | Justification |
|---|---|---|
| `NSOpenPanel` | `attachment-add-flow` | SwiftUI has no equivalent file-open panel API on macOS that allows "any file type" with a native sheet presentation. `fileImporter()` (SwiftUI) is limited to `UTType` allowlists and does not support the same UX flexibility. AppKit is the correct choice per §I. |
| `NSSavePanel` | `attachment-view-flow` | SwiftUI `fileExporter()` requires a `FileDocument` conformance which is inappropriate for arbitrary binary data being written outside the app's document model. `NSSavePanel` is the correct choice. |
| `NSWorkspace.shared.open(_:)` | `attachment-view-flow` | SwiftUI and Foundation have no equivalent API for opening a file with the system default application on macOS. This is the only sanctioned approach. |
| `NSApplication.didBecomeActiveNotification` | `AttachmentTempFileManager` (App layer) | Required to sweep expired temp files when the app returns to foreground after suspension. No SwiftUI equivalent for app-lifecycle notifications at this granularity. |

### Feature Complexity (§VI)

| Feature | Justified complexity | Rejected simpler alternative |
|---|---|---|
| Upload-incomplete detection and retry UI | Without recovery, an interrupted upload leaves an attachment that permanently shows no Open/Save actions — broken UX with no self-service fix. Retry reuses two existing use cases (`Delete` + `Upload`) so no new architectural components are required. | Silently delete incomplete attachments on sync — destroys user intent with no warning and is worse for large files on unreliable connections. |

## SECURITY.md

This change adds a new class of encrypted data (file attachments) to the app. Before merging, `SECURITY.md` at the repo root MUST be updated to:
- Document that file attachments are encrypted using AES-256-CBC + HMAC-SHA256 with per-attachment keys
- Explain the two-layer key scheme (attachment key wrapped by cipher key)
- Note that attachment file data is never cached unencrypted on disk (temp file lifecycle described)
- Update the threat model to cover attachment-specific risks (temp file exposure window, upload interruption)

## Resolved Design Decisions

| Decision | Resolution |
|---|---|
| Should attachment metadata appear in search results? | No for v1 — search operates on vault item name/username/URL only |
| Size warning threshold | Warn (advisory) at 50 MB; hard block at 500 MB |
| Download URL source | Use `Attachment.url` from sync payload directly when non-nil; signed URLs expire — on 403, discard the stale URL and re-fetch a fresh signed URL via `GET /api/ciphers/{id}/attachment/{attachmentId}`, then retry the blob download once; if the retry also fails, surface "Download failed. If this keeps happening, try locking and unlocking your vault." and do not retry further |
| Cancel during upload (single-file and batch) | Allowed in both flows — Cancel button remains enabled while uploading; cancels all in-flight tasks, zeros buffers, dismisses sheet |
| Cipher key storage | Not in VaultItem — separate VaultKeyCache in Data layer (see Decision §6) |
| Concurrent drag-drop during active upload | Rejected — drop zone shows rejection indicator and brief inline message; user may retry after current batch completes |
| Streaming encryption for large files | Not required for v1 — 500 MB hard limit is sufficient for in-memory encrypt/decrypt on macOS; deferred to future optimisation |
