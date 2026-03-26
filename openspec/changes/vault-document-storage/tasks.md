## 1. Domain Layer

- [ ] 1.1 Add `Attachment` struct to `Domain/Entities/` with fields: `id`, `fileName`, `encryptedFileName`, `encryptedKey`, `size`, `url`
- [ ] 1.2 Add `attachments: [Attachment]` field to the cipher detail entity (or equivalent `VaultItem` sub-type); treat `null` from server as `[]`
- [ ] 1.3 Define `AttachmentRepository` protocol in `Domain/` with `upload`, `download`, and `delete` methods
- [ ] 1.4 Implement `UploadAttachmentUseCase`, `DownloadAttachmentUseCase`, `DeleteAttachmentUseCase` in `Domain/UseCases/`; each holds an injected `AttachmentRepository` and exposes a single `execute(...)` method; no CryptoKit or URLSession imports
- [ ] 1.5 Write unit tests for `Attachment` value semantics and null-attachments-as-empty-array mapping
- [ ] 1.6 Write unit tests for all three use cases with a mock `AttachmentRepository` — verify correct delegation and error propagation

## 2. Crypto Layer

- [ ] 2.1 Add `generateAttachmentKey() throws -> Data` (64-byte random key via `SecRandomCopyBytes`) to `BitwardenCryptoService`
- [ ] 2.2 Add `encryptData(_ data: Data, attachmentKey: Data) throws -> Data` — AES-256-CBC + HMAC-SHA256, binary layout: IV ‖ ciphertext ‖ HMAC
- [ ] 2.3 Add `decryptData(_ data: Data, attachmentKey: Data) throws -> Data` — verify MAC before decrypt (Encrypt-then-MAC)
- [ ] 2.4 Add `encryptAttachmentKey(_ key: Data, cipherKey: SymmetricKey) throws -> String` — wraps attachment key as EncString type 2
- [ ] 2.5 Add `decryptAttachmentKey(_ encString: String, cipherKey: SymmetricKey) throws -> Data` — unwraps EncString → raw 64-byte key
- [ ] 2.6 Add `encryptFileName(_ name: String, cipherKey: SymmetricKey) throws -> String` — encrypt file name as EncString for upload metadata
- [ ] 2.7 Write unit tests: round-trip encrypt/decrypt of binary data; MAC tampering throws; attachment key wrap/unwrap round-trip; key zeroisation after use
- [ ] 2.8 Write Known-Answer Tests (KATs) — AES-CBC against NIST SP 800-38A vectors, HMAC-SHA256 against RFC 4231 vectors, and a full EncString round-trip KAT against a reference vector (required by §IV)

## 3. Data Layer — Network

- [ ] 3.1 Create `AttachmentRepositoryImpl` conforming to `AttachmentRepository`
- [ ] 3.2 Implement `upload` — generate attachment key, encrypt file name, encrypt file data, POST metadata to `/api/ciphers/{id}/attachment`, dispatch to `fileUploadType` 0 (Vaultwarden POST multipart) or 1 (Azure PUT + `x-ms-blob-type` header), zero key material after completion
- [ ] 3.3 Implement `download` — GET `/api/ciphers/{id}/attachment/{attachmentId}` for signed URL, GET encrypted blob from signed URL, decrypt with attachment key (decrypted from `encryptedKey`), zero key and ciphertext buffers after decryption; retry once on 403 (expired URL)
- [ ] 3.4 Implement `delete` — DELETE `/api/ciphers/{id}/attachment/{attachmentId}`, remove from in-memory cache on 200
- [ ] 3.5 Handle HTTP 402 response from upload → throw typed `AttachmentError.premiumRequired`
- [ ] 3.6 Register `AttachmentRepositoryImpl` in `AppContainer` (DI)
- [ ] 3.7 Add `os.Logger(subsystem: "com.macwarden", category: "attachments")` to `AttachmentRepositoryImpl`; log upload start/success at `.debug`/`.info`, network failures at `.error`, unrecoverable states at `.fault`; confirm no key material appears in any log message (§V)
- [ ] 3.8 Write integration tests for upload (mock server, both fileUploadType 0 and 1), download (mock signed URL), delete, and 402 premium error path

## 4. Data Layer — Sync Mapping

- [ ] 4.1 Create `AttachmentMapper` to convert sync JSON attachment object → `Attachment` entity, decrypting `fileName` from EncString using cipher key
- [ ] 4.2 Update `VaultSyncMapper` (or equivalent) to map `ciphers[].attachments` array through `AttachmentMapper`; coerce `null` to `[]`
- [ ] 4.3 Write unit tests for `AttachmentMapper`: encrypted file name is decrypted; `null` attachments field → empty array; `encryptedKey` preserved verbatim

## 5. Presentation — Attachments Section in Detail Pane

- [ ] 5.1 Add an Attachments section card to the vault item detail view below all existing field cards, using design system tokens (`Typography.sectionHeader`, `Spacing.cardTop/cardBottom/rowVertical/rowHorizontal`)
- [ ] 5.2 Render one `AttachmentRowView` per `Attachment` in the list, showing decrypted file name and human-readable size
- [ ] 5.3 Add "Add Attachment" button at the bottom of the Attachments card (visible even when attachment list is empty)

## 6. Presentation — Add Attachment Flow

- [ ] 6.1 Create `AttachmentAddViewModel` (`@Observable`) with state: `selectedFileURL`, `fileName`, `fileSizeBytes`, `isConfirming`, `isUploading`, `sizeError`, `uploadError`
- [ ] 6.2 Implement file selection via `NSOpenPanel`; read file size only (not contents) to validate ≤500 MB before reading bytes
- [ ] 6.3 Create `AttachmentConfirmSheet` — shows file name, size, size/advisory messages, progress indicator, Confirm/Cancel buttons; wired to `AttachmentAddViewModel`
- [ ] 6.4 Implement Confirm action — background `Task`, call `UploadAttachmentUseCase.execute(...)` (never the repository directly — §II), handle 402 (premium), handle vault lock (cancel task + zero buffers + dismiss), show progress
- [ ] 6.5 Write unit tests for `AttachmentAddViewModel`: 500 MB rejection, 50–500 MB advisory, successful upload path, vault lock abort, premium error display

## 7. Presentation — View / Download / Delete Flow

- [ ] 7.1 Create `AttachmentRowViewModel` per attachment row (`@Observable`) with state: `isLoading`, `actionError`
- [ ] 7.2 Implement Open action — background `Task`, call `DownloadAttachmentUseCase.execute(...)` (never the repository directly — §II), write plaintext to `FileManager.default.temporaryDirectory/<uuid>.<ext>`, `NSWorkspace.shared.open`, schedule 30-second zero+delete of temp file
- [ ] 7.3 Implement Save to Disk action — `NSSavePanel` pre-filled with `attachment.fileName`, on confirm call `DownloadAttachmentUseCase.execute(...)`, write to chosen path, zero buffer; no-op on cancel
- [ ] 7.4 Implement Delete action — show confirmation alert with file name, call `DeleteAttachmentUseCase.execute(...)` on confirm, remove row from list on success, show inline error on failure
- [ ] 7.5 Write unit tests for `AttachmentRowViewModel`: Open error path, Save to Disk cancel (no download triggered), Delete confirm vs cancel

## 8. Documentation & Transparency

- [ ] 8.1 Update `SECURITY.md` at repo root to document: attachment encryption scheme (AES-256-CBC + HMAC-SHA256 two-layer), where keys live (cipher key from Keychain → attachment key in memory only), temp file lifetime, and attachment-specific threat model additions (§VII)

## 9. XCUITest

- [ ] 9.1 Write UI journey: open a vault item → click Add Attachment → select a small test file → confirm → verify attachment row appears with correct name → click Open → verify temp file exists → click Delete → confirm → verify row is gone
