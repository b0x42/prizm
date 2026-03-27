## 1. Domain Layer

- [ ] 1.1 Add `Attachment` struct to `Domain/Entities/` with fields: `id: String`, `fileName: String`, `encryptedFileName: String`, `encryptedKey: String`, `size: Int`, `sizeName: String`, `url: String?`, `isUploadIncomplete: Bool` (defaults to `false`)
- [ ] 1.2 Add `attachments: [Attachment]` field to the cipher detail entity (or equivalent `VaultItem` sub-type); treat `null` from server as `[]`
- [ ] 1.3 Define `AttachmentRepository` protocol in `Domain/` with `upload(cipherId:fileName:data:cipherKey:)`, `download(cipherId:attachment:cipherKey:)`, and `delete(cipherId:attachmentId:)` methods
- [ ] 1.4 Define `VaultKeyService` protocol in `Domain/` with `cipherKey(for cipherId: String) async throws -> Data`; Foundation-only; throws when vault is locked
- [ ] 1.5 Implement `UploadAttachmentUseCase`, `DownloadAttachmentUseCase`, `DeleteAttachmentUseCase` in `Domain/UseCases/`; each injects `AttachmentRepository` + `VaultKeyService`; use case calls `vaultKeyService.cipherKey(for:)` internally and forwards to repository — `cipherKey` is never a parameter on the `execute(...)` method visible to callers
- [ ] 1.6 Write unit tests for `Attachment` value semantics and null-attachments-as-empty-array mapping
- [ ] 1.7 Write unit tests for all three use cases with mock `AttachmentRepository` + `VaultKeyService` — verify key is fetched internally and never appears in `execute(...)` parameter; verify vault-locked error propagates correctly

## 2. Crypto Layer

- [ ] 2.1 Add `generateAttachmentKey() throws -> Data` (64-byte random key via `SecRandomCopyBytes`) to `BitwardenCryptoService`
- [ ] 2.2 Add `encryptData(_ data: Data, attachmentKey: Data) throws -> Data` — AES-256-CBC + HMAC-SHA256, binary layout: IV ‖ ciphertext ‖ HMAC
- [ ] 2.3 Add `decryptData(_ data: Data, attachmentKey: Data) throws -> Data` — verify MAC before decrypt (Encrypt-then-MAC)
- [ ] 2.4 Add `encryptAttachmentKey(_ key: Data, cipherKey: SymmetricKey) throws -> String` — wraps attachment key as EncString type 2
- [ ] 2.5 Add `decryptAttachmentKey(_ encString: String, cipherKey: SymmetricKey) throws -> Data` — unwraps EncString → raw 64-byte key
- [ ] 2.6 Add `encryptFileName(_ name: String, cipherKey: SymmetricKey) throws -> String` — encrypt file name as EncString for upload metadata
- [ ] 2.7 Write unit tests: round-trip encrypt/decrypt of binary data; MAC tampering throws; attachment key wrap/unwrap round-trip; key zeroisation after use
- [ ] 2.8 Write Known-Answer Tests (KATs) — each test MUST cite the source inline (§IV + §VII):
  - AES-256-CBC: use NIST SP 800-38A Appendix F.2.5 (256-bit key, CBC mode) test vectors
  - HMAC-SHA256: use RFC 4231 §4.2 and §4.6 test vectors
  - EncString round-trip: derive a vector from the Bitwarden iOS client test suite (`BitwardenShared` test target, `CryptographyTests`) or the official Bitwarden security whitepaper; include the plaintext, key bytes, expected IV+ciphertext+MAC hex, and expected EncString string in the test source as comments

## 3. Data Layer — Network

- [ ] 3.1 Create `AttachmentRepositoryImpl` conforming to `AttachmentRepository`
- [ ] 3.2 Implement `upload` — generate attachment key, encrypt file name, encrypt file data, POST metadata to `/api/ciphers/{id}/attachment/v2`, dispatch to `fileUploadType` 0 (POST `/api/ciphers/{id}/attachment/{attachmentId}` multipart `data` field) or 1 (Azure PUT + `x-ms-blob-type: BlockBlob` header), zero key material after completion
- [ ] 3.3 Implement `download` — GET `/api/ciphers/{id}/attachment/{attachmentId}` for signed URL, GET encrypted blob from signed URL, decrypt with attachment key (decrypted from `encryptedKey`), zero key and ciphertext buffers after decryption; retry once on 403 (expired URL)
- [ ] 3.4 Implement `delete` — DELETE `/api/ciphers/{id}/attachment/{attachmentId}`, remove from in-memory cache on 200
- [ ] 3.5 Handle HTTP 402 response from upload → throw typed `AttachmentError.premiumRequired`
- [ ] 3.6 Register `AttachmentRepositoryImpl` in `AppContainer` (DI)
- [ ] 3.7 Add `os.Logger(subsystem: "com.macwarden", category: "attachments")` to `AttachmentRepositoryImpl`; log upload start/success at `.debug`/`.info`, network failures at `.error`, unrecoverable states at `.fault`; confirm no key material appears in any log message (§V)
- [ ] 3.8 Write integration tests for upload (mock server, both fileUploadType 0 and 1), download (mock signed URL), delete, and 402 premium error path

## 4. Data Layer — Sync Mapping

- [ ] 4.0 Define `AttachmentDTO` struct in the Data layer mirroring the sync JSON shape: `id: String`, `fileName: String` (EncString), `key: String` (EncString), `size: String`, `sizeName: String`, `url: String?`; derive `Decodable` conformance
- [ ] 4.1 Create `AttachmentMapper` with signature `map(_ dto: AttachmentDTO, cipherKey: Data) throws -> Attachment`; decrypt `fileName` from EncString; parse `size` String → Int (throw on failure); map `sizeName` verbatim; set `isUploadIncomplete = (dto.url == nil)`
- [ ] 4.2 Update `VaultSyncMapper` (or equivalent) to map `ciphers[].attachments` array through `AttachmentMapper`; coerce `null` to `[]`
- [ ] 4.3 Write unit tests for `AttachmentMapper`: fileName decrypted; size String parsed to Int; non-numeric size throws; sizeName preserved verbatim; null attachments → empty array; encryptedKey preserved verbatim; `isUploadIncomplete` is `true` when `url` is nil, `false` when present

## 5. Presentation — Attachments Section in Detail Pane

- [ ] 5.1 Add an Attachments section card to the vault item detail view below all existing field cards, using design system tokens (`Typography.sectionHeader`, `Spacing.cardTop/cardBottom/rowVertical/rowHorizontal`)
- [ ] 5.2 Render one `AttachmentRowView` per `Attachment` in the list, showing `attachment.fileName` and `attachment.sizeName` (use server-provided string directly — do not reformat)
- [ ] 5.3 Add "Add Attachment" button at the bottom of the Attachments card (visible even when attachment list is empty)
- [ ] 5.4 Add `.onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform:)` to the Attachments section card; bind `isDragTargeted` to a highlight style (border or background tint)

## 6. Presentation — Add Attachment Flow

- [ ] 6.1 Create `AttachmentAddViewModel` (`@Observable`) with state for single-file flow: `selectedFileURL`, `fileName`, `fileSizeBytes`, `isConfirming`, `isUploading`, `sizeError`, `uploadError`
- [ ] 6.2 Implement file selection via `NSOpenPanel`; read file size only (not contents) to validate ≤500 MB before reading bytes
- [ ] 6.3 Create `AttachmentConfirmSheet` — shows file name, size, size/advisory messages, progress indicator, Confirm/Cancel buttons; wired to `AttachmentAddViewModel`
- [ ] 6.4 Implement Confirm action — background `Task`, call `UploadAttachmentUseCase.execute(cipherId:fileName:data:)` with no key parameter (key resolved internally by use case — §II/§III), handle 402 (premium), handle vault lock (cancel task + zero buffers + dismiss), show progress
- [ ] 6.5 Write unit tests for `AttachmentAddViewModel`: 500 MB rejection, 50–500 MB advisory, successful upload path, vault lock abort, premium error display

## 6b. Presentation — Drag-and-Drop Batch Upload Flow

- [ ] 6b.1 Create `AttachmentBatchItem` model: `url: URL`, `fileName: String`, `sizeName: String`, `sizeBytes: Int`, `state: BatchItemState` (enum: `.valid`, `.tooLarge`, `.uploading`, `.succeeded`, `.failed(String)`)
- [ ] 6b.2 Create `AttachmentBatchViewModel` (`@Observable`) — accepts `[URL]` from drop handler; builds `[AttachmentBatchItem]` reading file size only (not contents); exposes `canConfirm: Bool` (true if ≥1 valid item); exposes `isUploading: Bool` (true while any task is in flight)
- [ ] 6b.3 Create `AttachmentBatchSheet` — lists all items with name, sizeName, per-row state (error badge for too-large, spinner for uploading, checkmark for success, error message for failed); Confirm/Cancel buttons driven by `canConfirm`; Cancel button remains enabled during upload (pressing it cancels all in-flight tasks, zeros buffers, dismisses sheet)
- [ ] 6b.4 Implement `.onDrop` handler in the Attachments section view — extract file URLs from `NSItemProvider`; if `isUploading` is true, reject the drop and show a brief inline message "Upload in progress — please wait"; otherwise pass URLs to `AttachmentBatchViewModel` and present `AttachmentBatchSheet`
- [ ] 6b.5 Implement Confirm action in `AttachmentBatchViewModel` — launch a concurrent background `Task` per valid item; each calls `UploadAttachmentUseCase.execute(cipherId:fileName:data:)`; update per-item state on success/failure; zero file bytes after each upload; dismiss sheet automatically when all succeed
- [ ] 6b.6 Handle vault lock during batch — cancel all in-flight upload tasks, zero all buffered file bytes, dismiss sheet immediately
- [ ] 6b.7 Implement Cancel-during-upload in `AttachmentBatchViewModel` — cancel all `Task` handles, zero all in-memory file byte buffers, set state to allow dismissal; files already partially uploaded appear as "Upload incomplete" on next sync
- [ ] 6b.8 Write unit tests for `AttachmentBatchViewModel`: all-too-large disables confirm; mixed valid/invalid shows correct states; concurrent upload tasks update item state independently; vault lock cancels all tasks; cancel-during-upload zeros all buffers; second drop while `isUploading` is rejected

## 6c. Data Layer — Upload-Incomplete Detection

- [ ] 6c.1 `AttachmentMapper` already sets `isUploadIncomplete` (task 4.1); verify `VaultSyncMapper` propagates this flag through to the in-memory vault cache so `AttachmentRowViewModel` can observe it

## 6d. Presentation — Upload-Incomplete UI

- [ ] 6d.1 In `AttachmentRowView`, render an "Upload incomplete" indicator (e.g. a warning icon + label) and a "Retry Upload" button when `attachment.isUploadIncomplete` is true; hide the normal Open/Save to Disk actions for that row
- [ ] 6d.2 Implement Retry Upload action — open `NSOpenPanel`; on confirmation: (1) call `DeleteAttachmentUseCase.execute(cipherId:attachmentId:)` to remove orphaned server metadata, then (2) call `UploadAttachmentUseCase.execute(cipherId:fileName:data:)` as a fresh upload; on success the incomplete row disappears and a new normal row appears; show inline error if either step fails
- [ ] 6d.3 Write unit tests for the incomplete-attachment row state and retry flow

## 7. Presentation — View / Download / Delete Flow

- [ ] 7.1 Create `AttachmentRowViewModel` per attachment row (`@Observable`) with state: `isLoading`, `actionError`
- [ ] 7.2 Implement Open action — background `Task`, call `DownloadAttachmentUseCase.execute(cipherId:attachment:)` with no key parameter (§II/§III), write plaintext to `FileManager.default.temporaryDirectory/<uuid>.<ext>`, `NSWorkspace.shared.open`, schedule 30-second zero+delete of temp file
- [ ] 7.3 Implement Save to Disk action — `NSSavePanel` pre-filled with `attachment.fileName`, on confirm call `DownloadAttachmentUseCase.execute(cipherId:attachment:)` with no key parameter, write to chosen path, zero buffer; no-op on cancel
- [ ] 7.4 Implement Delete action — show confirmation alert with file name, call `DeleteAttachmentUseCase.execute(...)` on confirm, remove row from list on success, show inline error on failure
- [ ] 7.5 Write unit tests for `AttachmentRowViewModel`: Open error path, Save to Disk cancel (no download triggered), Delete confirm vs cancel

## 8. Documentation & Transparency

- [ ] 8.1 Update `SECURITY.md` at repo root to document: attachment encryption scheme (AES-256-CBC + HMAC-SHA256 two-layer key scheme, three encrypted artifacts), where keys live (cipher key from Keychain → attachment key in memory only), temp file lifetime, and attachment-specific threat model additions (§VII)
- [ ] 8.2 Add §VII-compliant doc-comment blocks to every Data layer file that touches crypto for this feature — at minimum: `AttachmentRepositoryImpl`, `AttachmentMapper`, and any `BitwardenCryptoService` extension. Each block SHALL state the security goal, name the algorithm + spec ref, call out any deviations, and note any intentional omissions (e.g. no caching)

## 9. XCUITest

- [ ] 9.1 Write UI journey: open a vault item → click Add Attachment → select a small test file → confirm → verify attachment row appears with correct name → click Open → verify temp file exists → click Delete → confirm → verify row is gone
- [ ] 9.2 Write UI journey: open a vault item → drag two small test files onto the Attachments section → verify batch sheet lists both → confirm → verify both attachment rows appear
