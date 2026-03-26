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
- `func upload(cipherId: String, fileName: String, data: Data, cipherKey: SymmetricKey) async throws -> Attachment`
- `func download(cipherId: String, attachment: Attachment, cipherKey: SymmetricKey) async throws -> Data`
- `func delete(cipherId: String, attachmentId: String) async throws`

The protocol SHALL NOT reference `URLSession`, `URLRequest`, or any concrete network type.

#### Scenario: AttachmentRepository is a pure protocol
- **WHEN** the Domain layer is compiled
- **THEN** `AttachmentRepository` SHALL compile with `import Foundation` only

---

### Requirement: AttachmentMapper translates sync payload to Attachment entity
The Data layer SHALL provide an `AttachmentMapper` that converts the raw sync JSON object for an attachment into an `Attachment` domain entity, decrypting `fileName` from its EncString form using the provided cipher key.

#### Scenario: Mapper decrypts file name from EncString
- **WHEN** the mapper processes an attachment with `fileName` = `"2.<iv>|<ct>|<mac>"`
- **THEN** the resulting `Attachment.fileName` SHALL be the plaintext file name string

#### Scenario: Mapper preserves encrypted key as-is
- **WHEN** the mapper processes an attachment with a `key` field
- **THEN** `Attachment.encryptedKey` SHALL equal the raw EncString from the server without modification
