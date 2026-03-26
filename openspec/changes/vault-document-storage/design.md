## Context

Macwarden already stores five vault item types with end-to-end encryption using Bitwarden's AES-256-CBC + HMAC-SHA256 EncString scheme, backed by `BitwardenCryptoService`. The Bitwarden/Vaultwarden server provides a first-class Attachments API: file data is encrypted client-side, uploaded to the server (via a signed URL), and returned as part of the vault sync. Vaultwarden stores attachment files on disk or in S3-compatible storage; Bitwarden cloud requires a premium account.

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

### 1. Two-layer per-attachment encryption per Bitwarden whitepaper

**Decision:** For each attachment:
1. Generate a random 64-byte `attachmentKey` (32-byte enc key ‖ 32-byte mac key)
2. Encrypt file data with `attachmentKey` using AES-256-CBC + HMAC-SHA256 → `encryptedData`
3. Encrypt `attachmentKey` with the cipher's own symmetric key (or the user's vault key if the cipher has no per-item key) → `encryptedAttachmentKey` (EncString type 2)
4. Upload `encryptedAttachmentKey` as metadata; upload `encryptedData` as the file blob

**Why this scheme:** This is the documented Bitwarden attachment crypto. It means each attachment has an independent key — compromising one attachment key does not expose any other attachment or vault item. It also matches what the server expects.

**Alternatives considered:**
- *Re-use cipher's vault key directly to encrypt file data* — simpler, but non-standard; server rejects metadata format and any future official Bitwarden client would fail to decrypt
- *Streaming encryption* — not needed for ≤500 MB with macOS memory; adds complexity for no current benefit

### 2. Signed-URL upload pattern

**Decision:** Follow the two-step upload flow:
1. `POST /api/ciphers/{id}/attachment` with JSON metadata (fileName, key = `encryptedAttachmentKey`, fileSize) → server returns `{ attachmentId, url, fileUploadType }` where `url` is a signed upload URL
2. `PUT <signed-url>` with the raw encrypted blob as the request body

**Why:** This is the server's required flow. Attempting to send the file directly in the POST would violate the API contract.

**Vaultwarden note:** Vaultwarden supports `fileUploadType` = `0` (direct) where the signed URL points back to `POST /api/ciphers/{id}/attachment/{attachmentId}`. Handle both `0` (direct) and `1` (Azure blob) upload types.

### 3. Download on demand, not prefetch

**Decision:** Attachment file data is NOT downloaded during vault sync. Only attachment metadata (id, fileName, size, `encryptedAttachmentKey`) is stored in the in-memory vault cache. The file is fetched and decrypted only when the user explicitly clicks Open or Save to Disk.

**Why:** Attachments can be up to 500 MB each; prefetching all attachments on sync would be impractical and wasteful. Metadata is lightweight and sufficient for the list view.

### 4. No local caching of decrypted attachment data

**Decision:** Decrypted file data is NEVER written to a persistent store. For "Open", write the plaintext to a `FileManager` temp directory, open with `NSWorkspace`, then overwrite with zeroes and delete after 30 seconds. For "Save to Disk", write directly to the user-chosen path and zero the in-memory buffer immediately after.

**Why:** Macwarden is a security app. Leaving decrypted files on disk — even in a temp directory — is a data exposure risk that the temp-file lifecycle mitigates.

### 5. 500 MB UI limit enforced before upload

**Decision:** Reject files larger than 500 MB (524 288 000 bytes) at the file picker stage, before reading file content into memory. Show a clear error. This matches the Bitwarden server limit.

### 6. Premium gate surfaced in UI, not enforced by the app

**Decision:** Macwarden does not check the user's Bitwarden premium status before showing the Add Attachment button. If the server rejects the upload (402 or error body indicating premium required), the app surfaces the server's error message inline. Vaultwarden users are unaffected.

**Rationale:** Proactively gating the feature requires an extra API call (profile fetch) and maintenance burden as Bitwarden changes its plan tiers. The server is the authoritative source; reflecting its error is sufficient.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Upload interrupted mid-way — server has metadata but no file | On next sync, detect attachments with metadata but no resolvable download URL; show "upload incomplete" state and offer retry/delete |
| Decrypted plaintext in memory during encrypt/decrypt of large file (up to 500 MB) | Stream-encrypt if file > 50 MB using `CryptoKit.AES.CBC` chunked; for ≤50 MB load fully into memory |
| `attachmentKey` zeroisation — Swift `Data` is CoW and may be copied | Use `withUnsafeMutableBytes` to zero in place; avoid passing `Data` containing key material across actor boundaries |
| Bitwarden cloud rejects upload with 402 (premium required) | Catch HTTP 402, show localised "Attachments require a Bitwarden Premium account" message |
| Signed upload URL expiry during slow upload | Re-request a new signed URL and retry once on 403 from the upload endpoint |

## Open Questions

- Should attachment metadata (fileName, size) be shown in search results? (Assumed no for v1 — search operates on vault item name/username/URL only)
- Should there be an attachment size warning (not a hard stop) for files between 50 MB and 500 MB? (Assumed yes — warn at 50 MB, block at 500 MB)
