## 1. Domain Layer

- [ ] 1.1 Add `Attachment` struct to `Domain/Entities/` with fields: `id: String`, `fileName: String`, `encryptedKey: String`, `size: Int`, `sizeName: String`, `url: String?`, `isUploadIncomplete: Bool` (defaults to `false`)
- [ ] 1.2 Add `attachments: [Attachment]` field to the cipher detail entity (or equivalent `VaultItem` sub-type); treat `null` from server as `[]`
- [ ] 1.3 Define `AttachmentRepository` protocol in `Domain/` with:
  - `func upload(cipherId: String, fileName: String, data: Data, cipherKey: Data) async throws -> Attachment`
  - `func download(cipherId: String, attachment: Attachment, cipherKey: Data) async throws -> Data`
  - `func delete(cipherId: String, attachmentId: String) async throws`
- [ ] 1.3a Add `func updateAttachments(_ attachments: [Attachment], for cipherId: String)` to the `VaultRepository` protocol and implement it in `VaultRepositoryImpl` — finds the item by ID and replaces its `attachments` array in-place; `AttachmentRepositoryImpl` injects `VaultRepository` and calls this after a successful upload (appending the new `Attachment`) or delete (removing the deleted ID) so the detail pane updates without a full re-sync, matching the pattern used by `VaultRepositoryImpl.update` and `.create`
- [ ] 1.4 Define `VaultKeyService` protocol in `Domain/` with `cipherKey(for cipherId: String) async throws -> Data`; Foundation-only; throws when vault is locked
- [ ] 1.5 Implement `UploadAttachmentUseCase`, `DownloadAttachmentUseCase`, `DeleteAttachmentUseCase` in `Domain/UseCases/`; each injects `AttachmentRepository` + `VaultKeyService`; use case calls `vaultKeyService.cipherKey(for:)` internally and forwards to repository — `cipherKey` is never a parameter on the `execute(...)` method visible to callers
- [ ] 1.6 Write unit tests for `Attachment` value semantics and null-attachments-as-empty-array mapping
- [ ] 1.7 Write unit tests for all three use cases with mock `AttachmentRepository` + `VaultKeyService` — verify key is fetched internally and never appears in `execute(...)` parameter; verify vault-locked error propagates correctly

## 1b. Data Layer — Cipher Key Cache

- [ ] 1b.1 Create `VaultKeyCache` class in the Data layer: stores `[String: Data]` (cipher ID → effective symmetric key); provides `populate(keys: [String: Data])`, `key(for cipherId: String) -> Data?`, and `clear()` methods; cleared on vault lock alongside `VaultRepositoryImpl`
- [ ] 1b.2 Update `CipherMapper.map(raw:keys:)` to also return the effective cipher key as `Data` — use `raw.key` (EncString, decrypt with vault key) if non-nil, otherwise use vault symmetric key directly; return as a tuple `(VaultItem, cipherKey: Data)` or equivalent; update ALL existing call sites (`SyncRepositoryImpl`, `VaultRepositoryImpl.update`, `VaultRepositoryImpl.create`) to destructure the new return type — these call sites discard the `cipherKey` value since they do not use it
- [ ] 1b.3 Update `SyncRepositoryImpl` (or wherever sync mapping is orchestrated) to collect the `cipherKey` values from each `CipherMapper.map` call and populate `VaultKeyCache` after sync completes; clear `VaultKeyCache` in the same code path that clears `VaultRepositoryImpl` on lock/sign-out
- [ ] 1b.4 Implement `VaultKeyServiceImpl` (Data layer) conforming to the Domain `VaultKeyService` protocol: reads from `VaultKeyCache` for the cipher's per-item key; if the cache has no entry for the cipher ID (either no per-item key exists, or cipher was created after last sync), fall back to the vault key by calling `crypto.currentKeys()` and concatenating `keys.encryptionKey + keys.macKey` → 64-byte `Data` (`CryptoKeys` has two separate 32-byte fields — `encryptionKey` and `macKey` — there is no `symmetricKey` field); if `currentKeys()` throws `PrizmCryptoServiceError.vaultLocked`, translate to `VaultError.vaultLocked` and rethrow — do NOT infer locked state from an empty or missing cache entry, as a missing entry is valid for newly created ciphers; add `os.Logger(subsystem: "com.prizm", category: "attachments")` — log vault-locked errors at `.error`, fallback-to-vault-key at `.debug`; no key material in log output (§V)
- [ ] 1b.5 Register `VaultKeyCache` and `VaultKeyServiceImpl` in `AppContainer` (DI); inject `VaultKeyServiceImpl` into the three attachment use cases
- [ ] 1b.6 Write unit tests for `VaultKeyCache`: populate/lookup/clear lifecycle; returns nil for unknown cipher ID; cleared state returns nil for all lookups
- [ ] 1b.7 Write unit tests for `VaultKeyServiceImpl`: returns per-item key when present in cache; falls back to vault key when cache entry is nil (cipher has no per-item key); falls back to vault key when cipher ID is absent from cache (newly created cipher, not yet synced); throws `VaultError.vaultLocked` when `currentKeys()` throws — NOT when the cache merely has no entry for that cipher ID

## 2. Crypto Layer

- [ ] 2.1 Add `generateAttachmentKey() throws -> Data` (64-byte random key via `SecRandomCopyBytes`) to `PrizmCryptoService`
- [ ] 2.2 Add `encryptData(_ data: Data, attachmentKey: Data) throws -> Data` — AES-256-CBC + HMAC-SHA256, binary layout: IV ‖ ciphertext ‖ HMAC
- [ ] 2.3 Add `decryptData(_ data: Data, attachmentKey: Data) throws -> Data` — verify MAC before decrypt (Encrypt-then-MAC)
- [ ] 2.4 Add `encryptAttachmentKey(_ key: Data, cipherKey: CryptoKeys) throws -> String` — wraps attachment key as EncString type 2 using `cipherKey.encryptionKey` for AES and `cipherKey.macKey` for HMAC; consistent with existing `CryptoKeys` usage in `CipherMapper`
- [ ] 2.5 Add `decryptAttachmentKey(_ encString: String, cipherKey: CryptoKeys) throws -> Data` — unwraps EncString → raw 64-byte key using `cipherKey.encryptionKey` / `cipherKey.macKey`
- [ ] 2.6 Add `encryptFileName(_ name: String, cipherKey: CryptoKeys) throws -> String` — encrypt file name as EncString for upload metadata using `cipherKey.encryptionKey` / `cipherKey.macKey`
- [ ] 2.7 Write unit tests: round-trip encrypt/decrypt of binary data; MAC tampering throws; attachment key wrap/unwrap round-trip; key zeroisation after use
- [ ] 2.8 Write Known-Answer Tests (KATs) — each test MUST cite the source inline (§IV + §VII):
  - AES-256-CBC: use NIST SP 800-38A Appendix F.2.5 (256-bit key, CBC mode) test vectors
  - HMAC-SHA256: use RFC 4231 §4.2 and §4.6 test vectors
  - EncString round-trip: derive a vector from the Bitwarden iOS client test suite (`BitwardenShared` test target, `CryptographyTests`) or the official Bitwarden security whitepaper; include the plaintext, key bytes, expected IV+ciphertext+MAC hex, and expected EncString string in the test source as comments

## 3. Data Layer — Network

- [ ] 3.1 Create `AttachmentRepositoryImpl` conforming to `AttachmentRepository`; at the Data layer boundary, convert the 64-byte `cipherKey: Data` received from the protocol into `CryptoKeys` by splitting: `encryptionKey = cipherKey[0..<32]`, `macKey = cipherKey[32..<64]` — then pass the resulting `CryptoKeys` to `PrizmCryptoService` methods (2.4–2.6)
- [ ] 3.2 Implement `upload` — generate attachment key, encrypt file name, encrypt file data, POST metadata to `/api/ciphers/{id}/attachment/v2`, dispatch to `fileUploadType` 0 (POST `/api/ciphers/{id}/attachment/{attachmentId}` multipart `data` field) or 1 (Azure PUT + `x-ms-blob-type: BlockBlob` header), zero key material after completion
- [ ] 3.3 Implement `download` — GET encrypted blob from `Attachment.url` if non-nil, otherwise fetch a fresh signed URL via GET `/api/ciphers/{id}/attachment/{attachmentId}` first; on 403, discard the stale URL, re-fetch a fresh signed URL, and retry the blob download once; if the retry also fails, throw `AttachmentError.downloadFailed` with message "Download failed. If this keeps happening, try locking and unlocking your vault."; decrypt blob with attachment key (decrypted from `encryptedKey`), zero key and ciphertext buffers after decryption
- [ ] 3.4 Implement `delete` — DELETE `/api/ciphers/{id}/attachment/{attachmentId}`, remove from in-memory cache on 200
- [ ] 3.5 Handle HTTP 402 response from upload → throw typed `AttachmentError.premiumRequired`
- [ ] 3.6 Register `AttachmentRepositoryImpl` in `AppContainer` (DI)
- [ ] 3.7 Add `os.Logger(subsystem: "com.prizm", category: "attachments")` to `AttachmentRepositoryImpl`; log upload start/success at `.debug`/`.info`, network failures at `.error`, unrecoverable states at `.fault`; confirm no key material appears in any log message (§V)
- [ ] 3.8 Write integration tests for upload (mock server, both fileUploadType 0 and 1), download (mock signed URL), delete, and 402 premium error path

## 4. Data Layer — Sync Mapping

- [ ] 4.0 Define `AttachmentDTO` struct in the Data layer mirroring the sync JSON shape: `id: String`, `fileName: String` (EncString), `key: String` (EncString), `size: String`, `sizeName: String`, `url: String?`; derive `Decodable` conformance; write unit tests for `AttachmentDTO` decoding: valid JSON decodes correctly; `url` absent or `null` decodes as `nil`; missing required field throws `DecodingError`
- [ ] 4.1 Create `AttachmentMapper` with signature `map(_ dto: AttachmentDTO, cipherKey: Data) throws -> Attachment`; decrypt `fileName` from EncString; parse `size` String → Int (throw on failure); map `sizeName` verbatim; set `isUploadIncomplete = (dto.url == nil)`; add `os.Logger(subsystem: "com.prizm", category: "attachments")` — log decryption failures at `.error` and non-numeric size at `.error`; no key material or file content in log output (§V)
- [ ] 4.2 Write unit tests for `AttachmentMapper`: fileName decrypted; size String parsed to Int; non-numeric size throws; sizeName preserved verbatim; null attachments → empty array; encryptedKey preserved verbatim; `isUploadIncomplete` is `true` when `url` is nil, `false` when present

## 5. Presentation — Attachments Section in Detail Pane

- [ ] 5.1 Add an Attachments section card to the vault item detail view below all existing field cards, using design system tokens (`Typography.sectionHeader`, `Spacing.cardTop/cardBottom/rowVertical/rowHorizontal`); the card is ALWAYS visible regardless of attachment count — it shows an empty state with just the "Add Attachment" button when the item has no attachments
- [ ] 5.2 Render one `AttachmentRowView` per `Attachment` in the list, showing `attachment.fileName` and `attachment.sizeName` (use server-provided string directly — do not reformat)
- [ ] 5.3 Add "Add Attachment" button at the bottom of the Attachments card (visible even when attachment list is empty)
- [ ] 5.4 Add `.onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform:)` to the Attachments section card; bind `isDragTargeted` to a highlight style (border or background tint)

## 6. Presentation — Add Attachment Flow

- [ ] 6.1 Create `AttachmentAddViewModel` (`@Observable`) with state for single-file flow: `selectedFileURL`, `fileName`, `fileSizeBytes`, `isConfirming`, `isUploading`, `sizeError`, `uploadError`, `uploadTask: Task<Void, Never>?` (held to support cancellation in 6.4b; set to nil after cancellation or completion)
- [ ] 6.2 Implement file selection via `NSOpenPanel`; read file size only (not contents) to validate ≤500 MB before reading bytes
- [ ] 6.3 Create `AttachmentConfirmSheet` — shows file name, size (formatted via `ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)`), size/advisory messages, progress indicator, Confirm/Cancel buttons; wired to `AttachmentAddViewModel`
- [ ] 6.4 Implement Confirm action — background `Task`: (1) read file bytes from `selectedFileURL` into memory at this point (not at file selection time — minimises how long raw data is held); (2) call `UploadAttachmentUseCase.execute(cipherId:fileName:data:)` with no key parameter (key resolved internally by use case — §II/§III); handle 402 (premium), handle vault lock (cancel task + zero buffers + dismiss), show progress; Cancel button remains enabled during upload
- [ ] 6.4b Implement Cancel-during-upload in `AttachmentAddViewModel` — cancel the in-flight upload `Task`, zero the in-memory file data buffer, dismiss the sheet immediately; no discard prompt
- [ ] 6.5 Write unit tests for `AttachmentAddViewModel`: 500 MB rejection, 50–500 MB advisory, successful upload path, vault lock abort, premium error display, cancel-during-upload zeros buffer and dismisses

## 6b. Presentation — Drag-and-Drop Batch Upload Flow

- [ ] 6b.1 Create `AttachmentBatchItem` model: `fileURL: URL` (local Finder URL from drop — distinct from `Attachment.url` which is a server download URL), `fileName: String`, `sizeName: String`, `sizeBytes: Int`, `state: BatchItemState` (enum: `.valid`, `.tooLarge`, `.uploading`, `.succeeded`, `.failed(String)`)
- [ ] 6b.2 Create `AttachmentBatchViewModel` (`@Observable`) — accepts `[URL]` from drop handler; assigns each dropped URL as the `fileURL` of an `AttachmentBatchItem`, reading file size only (not contents) to populate `sizeBytes`; compute `sizeName` locally using `ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)` (server has not yet seen the file at this point); holds `uploadTasks: [Task<Void, Never>]` (one per valid item, stored to support cancellation in 6b.7; cleared after all complete or are cancelled); exposes `canConfirm: Bool` (true if ≥1 valid item); exposes `isUploading: Bool` (true while any task is in flight)
- [ ] 6b.3 Create `AttachmentBatchSheet` — lists all items with name, sizeName, per-row state (error badge for too-large, spinner for uploading, checkmark for success, error message for failed); Confirm/Cancel buttons driven by `canConfirm`; Cancel button remains enabled during upload (pressing it cancels all in-flight tasks, zeros buffers, dismisses sheet)
- [ ] 6b.4 Implement `.onDrop` handler in the Attachments section view — extract file URLs from `NSItemProvider`; if `isUploading` is true, reject the drop and show a brief inline message "Upload in progress — please wait"; otherwise pass URLs to `AttachmentBatchViewModel` and present `AttachmentBatchSheet`
- [ ] 6b.5 Implement Confirm action in `AttachmentBatchViewModel` — launch a concurrent background `Task` per valid item; each: (1) reads the file bytes from `fileURL` into memory at this point (not at drop time — minimises how long raw data is held per file); (2) calls `UploadAttachmentUseCase.execute(cipherId:fileName:data:)`; update per-item state on success/failure; zero file bytes immediately after each upload completes; dismiss sheet automatically when all succeed
- [ ] 6b.6 Handle vault lock during batch — cancel all in-flight upload tasks, zero all buffered file bytes, dismiss sheet immediately
- [ ] 6b.7 Implement Cancel-during-upload in `AttachmentBatchViewModel` — cancel all `Task` handles, zero all in-memory file byte buffers, set state to allow dismissal; files already partially uploaded appear as "Upload incomplete" on next sync
- [ ] 6b.8 Write unit tests for `AttachmentBatchViewModel`: all-too-large disables confirm; mixed valid/invalid shows correct states; concurrent upload tasks update item state independently; vault lock cancels all tasks; cancel-during-upload zeros all buffers; second drop while `isUploading` is rejected

## 6c. Data Layer — Upload-Incomplete Detection

- [ ] 6c.1 Update `CipherMapper.map(raw:keys:)` (or the sync orchestration layer) to map `raw.attachments` through `AttachmentMapper` and populate `VaultItem.attachments`; coerce `null` to `[]`; confirm `isUploadIncomplete` (set in task 4.1) is preserved through the full chain from `AttachmentMapper` → `VaultItem` → in-memory vault cache → `AttachmentRowViewModel`; write a unit test asserting an attachment with `url: nil` surfaces as `isUploadIncomplete = true` on the cached `VaultItem`

## 6d. Presentation — Upload-Incomplete UI

- [ ] 6d.1 In `AttachmentRowView`, render an "Upload incomplete" indicator (e.g. a warning icon + label) and a "Retry Upload" button when `attachment.isUploadIncomplete` is true; hide the normal Open/Save to Disk actions for that row
- [ ] 6d.2 Implement Retry Upload action — open `NSOpenPanel`; on confirmation: (1) call `DeleteAttachmentUseCase.execute(cipherId:attachmentId:)` to remove orphaned server metadata, then (2) call `UploadAttachmentUseCase.execute(cipherId:fileName:data:)` as a fresh upload; on success the incomplete row disappears and a new normal row appears; show inline error if either step fails
- [ ] 6d.3 Write unit tests for the incomplete-attachment row state and retry flow

## 7. Presentation — View / Download / Delete Flow

- [ ] 7.1 Create `AttachmentRowViewModel` per attachment row (`@Observable`) with state: `isLoading: Bool`, `actionError: String?`, `isRetrying: Bool`, `retryError: String?`; the view derives whether to show normal actions or the incomplete-upload UI directly from `attachment.isUploadIncomplete` — no separate flag needed on the ViewModel
- [ ] 7.2 Create `AttachmentTempFileManager` (App layer — `App/`) responsible for temp file lifecycle: tracks `[(url: URL, deleteAfter: Date)]`; `register(url:)` records the file with a 30-second deletion deadline; `cleanup()` zeroes and deletes all entries past their deadline; registers for `NSApplication.didBecomeActiveNotification` and calls `cleanup()` on each foreground; placed in App layer because it imports AppKit (`NSApplication`) per §II; instantiate as a singleton in `AppContainer` and inject into `AttachmentRowViewModel` via its initialiser so ViewModels never import App layer directly — inject as a protocol (`TempFileManaging`) to keep Presentation layer clean
- [ ] 7.2a Define `TempFileManaging` protocol in the Presentation layer (`Presentation/`) with `func register(url: URL)` and `func cleanup()`; placed in Presentation (not Domain) because it is an infrastructure concern, not a business rule — Domain must remain pure per §II; `AttachmentTempFileManager` (App layer) conforms to it — App layer may import Presentation; `AttachmentRowViewModel` depends on `any TempFileManaging` — never the concrete App-layer type
- [ ] 7.2b Implement Open action in `AttachmentRowViewModel` — background `Task`, call `DownloadAttachmentUseCase.execute(cipherId:attachment:)` with no key parameter (§II/§III), write plaintext to `FileManager.default.temporaryDirectory/<uuid>.<ext>`, call `NSWorkspace.shared.open`, register the temp file with `tempFileManager.register(url:)`; schedule a `Task.sleep(for: .seconds(30))` + `tempFileManager.cleanup()` call to handle the common case where the app stays in foreground
- [ ] 7.2c Write unit tests for `AttachmentTempFileManager`: `register` adds entry with correct deadline; `cleanup` zeroes and deletes files past their deadline; `cleanup` leaves files not yet past deadline untouched; foreground notification triggers `cleanup`
- [ ] 7.3 Implement Save to Disk action — `NSSavePanel` pre-filled with `attachment.fileName`, on confirm call `DownloadAttachmentUseCase.execute(cipherId:attachment:)` with no key parameter, write to chosen path, zero buffer; no-op on cancel
- [ ] 7.4 Implement Delete action — show confirmation alert with file name, call `DeleteAttachmentUseCase.execute(...)` on confirm, remove row from list on success, show inline error on failure
- [ ] 7.5 Write unit tests for `AttachmentRowViewModel`: Open error path, Save to Disk cancel (no download triggered), Delete confirm vs cancel

## 8. Documentation & Transparency

- [ ] 8.1 Update `SECURITY.md` at repo root to document: attachment encryption scheme (AES-256-CBC + HMAC-SHA256 two-layer key scheme, three encrypted artifacts), where keys live (cipher key from Keychain → attachment key in memory only), temp file lifetime, and attachment-specific threat model additions (§VII)
- [ ] 8.2 Add §VII-compliant doc-comment blocks to every Data layer file that touches crypto or key material for this feature — at minimum: `AttachmentRepositoryImpl`, `AttachmentMapper`, `VaultKeyCache`, `VaultKeyServiceImpl`, and any `PrizmCryptoService` extension. Each block SHALL state the security goal, name the algorithm or key-handling scheme + spec ref, call out any deviations, and note any intentional omissions (e.g. no caching, no key persistence beyond vault lock)

## 9. XCUITest

- [ ] 9.1 Write UI journey: open a vault item → click Add Attachment → select a small test file → confirm → verify attachment row appears with correct name → click Open → verify a progress indicator appears then clears (temp file verification is not practical from XCUITest; open success is inferred from loading state resolving without error) → click Delete → confirm → verify row is gone
- [ ] 9.2 Write UI journey: open a vault item → drag two small test files onto the Attachments section → verify batch sheet lists both → confirm → verify both attachment rows appear
