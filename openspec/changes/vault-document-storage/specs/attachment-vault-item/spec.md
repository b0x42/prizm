## ADDED Requirements

### Requirement: Attachment domain entity
The system SHALL define an `Attachment` value type (`struct`) in the Domain layer with fields: `id: String`, `fileName: String` (decrypted), `encryptedFileName: String` (EncString, as received from server), `encryptedKey: String` (EncString — the attachment key wrapped with the cipher key), `size: Int`, `url: String?`. The Domain layer SHALL NOT import CommonCrypto, CryptoKit, or any Data-layer module.

#### Scenario: Attachment is a pure value type with no crypto imports
- **WHEN** the Domain layer is compiled
- **THEN** `Attachment` SHALL compile with `import Foundation` only

#### Scenario: Attachment exposes both encrypted and decrypted file name
- **WHEN** an `Attachment` is inspected
- **THEN** it SHALL expose `fileName` (plaintext, for display) and `encryptedFileName` (EncString, for upload metadata)

---

### Requirement: CipherDetail includes attachments array
The system SHALL add an `attachments: [Attachment]` field to the cipher detail entity (or equivalent `VaultItem` sub-type). The field SHALL be populated during vault sync from the `ciphers[].attachments` array in the `GET /api/sync` response. An empty array means no attachments; `null` from the server SHALL be treated as an empty array.

#### Scenario: Vault sync populates attachments on existing items
- **WHEN** the vault sync response includes a cipher with an `attachments` array
- **THEN** the in-memory vault item SHALL have an `attachments` array matching the sync data

#### Scenario: Null attachments field treated as empty
- **WHEN** a cipher's `attachments` field is `null` in the sync response
- **THEN** the in-memory `attachments` array SHALL be `[]`, not `nil`

---

### Requirement: AttachmentRepository protocol
The Domain layer SHALL define an `AttachmentRepository` protocol with:
- `func upload(cipherId: String, fileName: String, data: Data, cipherKey: Data) async throws -> Attachment`
- `func download(cipherId: String, attachment: Attachment, cipherKey: Data) async throws -> Data`
- `func delete(cipherId: String, attachmentId: String) async throws`

The `cipherKey` parameter SHALL be a raw `Data` value (the 64-byte vault symmetric key material) — NOT a `SymmetricKey` or any other CryptoKit type. Using a CryptoKit type in a Domain protocol would require importing CryptoKit in the Domain layer, violating the clean architecture boundary (§II). The Data layer is responsible for interpreting the raw bytes as a `SymmetricKey` at the point of use. The protocol SHALL NOT reference `URLSession`, `URLRequest`, or any concrete network type.

#### Scenario: AttachmentRepository is a pure protocol
- **WHEN** the Domain layer is compiled
- **THEN** `AttachmentRepository` SHALL compile with `import Foundation` only — no CryptoKit, CommonCrypto, or Security imports

---

### Requirement: Attachment use cases in Domain layer
The Domain layer SHALL define three use cases that the Presentation layer calls exclusively — ViewModels MUST NOT import or reference `AttachmentRepository` or any Data layer type directly (§II). Use cases translate between domain entities and raw types at the layer boundary:

- `UploadAttachmentUseCase`: accepts `cipherId: String`, `fileName: String`, `data: Data`, `cipherKey: Data`; delegates to `AttachmentRepository.upload`; returns `Attachment`
- `DownloadAttachmentUseCase`: accepts `cipherId: String`, `attachment: Attachment`, `cipherKey: Data`; delegates to `AttachmentRepository.download`; returns `Data`
- `DeleteAttachmentUseCase`: accepts `cipherId: String`, `attachmentId: String`; delegates to `AttachmentRepository.delete`

Each use case SHALL be a struct or final class in `Domain/UseCases/` that holds an `AttachmentRepository` reference via protocol (injected at construction). No use case SHALL import URLSession, CryptoKit, or any Data layer module.

#### Scenario: ViewModel calls upload use case, not repository
- **WHEN** the Presentation layer initiates an attachment upload
- **THEN** it SHALL call `UploadAttachmentUseCase.execute(...)` — never `AttachmentRepository.upload` directly

#### Scenario: ViewModel calls download use case, not repository
- **WHEN** the Presentation layer requests an attachment download
- **THEN** it SHALL call `DownloadAttachmentUseCase.execute(...)` — never `AttachmentRepository.download` directly

#### Scenario: ViewModel calls delete use case, not repository
- **WHEN** the Presentation layer deletes an attachment
- **THEN** it SHALL call `DeleteAttachmentUseCase.execute(...)` — never `AttachmentRepository.delete` directly

---

### Requirement: AttachmentMapper translates sync payload to Attachment entity
The Data layer SHALL provide an `AttachmentMapper` that converts the raw sync JSON object for an attachment into an `Attachment` domain entity, decrypting `fileName` from its EncString form using the provided cipher key.

#### Scenario: Mapper decrypts file name from EncString
- **WHEN** the mapper processes an attachment with `fileName` = `"2.<iv>|<ct>|<mac>"`
- **THEN** the resulting `Attachment.fileName` SHALL be the plaintext file name string

#### Scenario: Mapper preserves encrypted key as-is
- **WHEN** the mapper processes an attachment with a `key` field
- **THEN** `Attachment.encryptedKey` SHALL equal the raw EncString from the server without modification
