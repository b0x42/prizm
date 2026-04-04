## ADDED Requirements

### Requirement: Attachment domain entity
The system SHALL define an `Attachment` value type (`struct`) in the Domain layer with fields: `id: String`, `fileName: String` (decrypted), `encryptedKey: String` (EncString — the attachment key wrapped with the cipher key), `size: Int` (parsed from the server's string representation), `sizeName: String` (human-readable size string as returned by server, e.g. `"1.5 MB"` — used directly in UI, not re-formatted client-side per §VI), `url: String?`, `isUploadIncomplete: Bool` (true when `url` is nil, indicating the blob upload was interrupted after metadata creation). The Domain layer SHALL NOT import CommonCrypto, CryptoKit, or any Data-layer module.

Note on `size`: the Bitwarden API returns `size` as a JSON string (e.g. `"12345"`), not a number. `AttachmentMapper` SHALL parse it to `Int`; if parsing fails the mapper SHALL throw a typed error.

#### Scenario: Attachment is a pure value type with no crypto imports
- **WHEN** the Domain layer is compiled
- **THEN** `Attachment` SHALL compile with `import Foundation` only

#### Scenario: Attachment exposes decrypted file name for display
- **WHEN** an `Attachment` is inspected
- **THEN** it SHALL expose `fileName` (plaintext, for display); the encrypted form is not stored on the entity (§VI — not needed after mapping)

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

### Requirement: VaultKeyService protocol in Domain layer
The Domain layer SHALL define a `VaultKeyService` protocol that provides the symmetric key for a given cipher on demand:

```
func cipherKey(for cipherId: String) async throws -> Data
```

The protocol SHALL return raw `Data` (64-byte enc ‖ mac key material) and SHALL compile with `import Foundation` only. The Data layer implements this by reading the in-memory decrypted vault key. If the vault is locked, the call SHALL throw a typed error.

This protocol exists so Use Cases can resolve cipher keys internally without the Presentation layer ever handling key material, satisfying §II and §III.

#### Scenario: VaultKeyService is a pure Domain protocol
- **WHEN** the Domain layer is compiled
- **THEN** `VaultKeyService` SHALL compile with `import Foundation` only

#### Scenario: VaultKeyService throws when vault is locked
- **WHEN** `cipherKey(for:)` is called while the vault is locked
- **THEN** it SHALL throw a typed error — the use case propagates this to the ViewModel as a display error, never as raw key material

---

### Requirement: Attachment use cases in Domain layer
The Domain layer SHALL define three use cases that the Presentation layer calls exclusively — ViewModels MUST NOT import or reference `AttachmentRepository`, `VaultKeyService`, or any Data layer type directly (§II). Use cases resolve the cipher key internally via an injected `VaultKeyService`; key material MUST NOT be passed through or held by the Presentation layer (§III).

Use case signatures (no `cipherKey` parameter — the use case fetches it internally):

- `UploadAttachmentUseCase.execute(cipherId: String, fileName: String, data: Data) async throws -> Attachment`
- `DownloadAttachmentUseCase.execute(cipherId: String, attachment: Attachment) async throws -> Data`
- `DeleteAttachmentUseCase.execute(cipherId: String, attachmentId: String) async throws`

Each use case SHALL be a struct or final class in `Domain/UseCases/` holding injected `AttachmentRepository` and `VaultKeyService` references (protocol types only). No use case SHALL import URLSession, CryptoKit, or any Data layer module. Internally, each relevant use case calls `vaultKeyService.cipherKey(for: cipherId)` and forwards the result to the repository — the key is never surfaced to the caller.

#### Scenario: ViewModel calls upload use case with no key parameter
- **WHEN** the Presentation layer initiates an attachment upload
- **THEN** it SHALL call `UploadAttachmentUseCase.execute(cipherId:fileName:data:)` — never passing a key, never calling `AttachmentRepository.upload` directly

#### Scenario: ViewModel calls download use case with no key parameter
- **WHEN** the Presentation layer requests an attachment download
- **THEN** it SHALL call `DownloadAttachmentUseCase.execute(cipherId:attachment:)` — no key parameter; the use case resolves it internally

#### Scenario: ViewModel calls delete use case, not repository
- **WHEN** the Presentation layer deletes an attachment
- **THEN** it SHALL call `DeleteAttachmentUseCase.execute(cipherId:attachmentId:)` — never `AttachmentRepository.delete` directly

#### Scenario: Key material is never held by a ViewModel
- **WHEN** any attachment use case executes
- **THEN** the calling ViewModel SHALL receive only domain entities or errors — never raw key bytes

---

### Requirement: AttachmentMapper translates sync payload to Attachment entity
The Data layer SHALL provide an `AttachmentMapper` with the following signature:

```swift
func map(_ dto: AttachmentDTO, cipherKey: Data) throws -> Attachment
```

`AttachmentDTO` mirrors the raw sync JSON shape: `{ "id": String, "fileName": EncString, "key": EncString, "size": String, "sizeName": String, "url": String? }`. `VaultSyncMapper` (or equivalent) SHALL call `AttachmentMapper.map(_:cipherKey:)` for each element of `ciphers[].attachments`, supplying the cipher's resolved key. The mapper SHALL:
- Decrypt `fileName` from its EncString form using the provided cipher key → `Attachment.fileName`
- Preserve `key` EncString verbatim → `Attachment.encryptedKey`
- Parse `size` from `String` to `Int` → `Attachment.size`; throw a typed error if non-numeric
- Map `sizeName` verbatim → `Attachment.sizeName`
- Map `url` verbatim (may be `null`) → `Attachment.url`
- Set `isUploadIncomplete = (url == nil)` → `Attachment.isUploadIncomplete`; a nil URL means the blob upload was interrupted after the metadata POST succeeded

#### Scenario: Mapper sets isUploadIncomplete when url is nil
- **WHEN** the mapper processes an attachment with `url` = `null`
- **THEN** `Attachment.isUploadIncomplete` SHALL be `true`

#### Scenario: Mapper clears isUploadIncomplete when url is present
- **WHEN** the mapper processes an attachment with a non-nil `url`
- **THEN** `Attachment.isUploadIncomplete` SHALL be `false`

#### Scenario: Mapper decrypts file name from EncString
- **WHEN** the mapper processes an attachment with `fileName` = `"2.<iv>|<ct>|<mac>"`
- **THEN** the resulting `Attachment.fileName` SHALL be the plaintext file name string

#### Scenario: Mapper parses size string to Int
- **WHEN** the mapper processes an attachment with `size` = `"12345"`
- **THEN** `Attachment.size` SHALL equal `12345` as an `Int`

#### Scenario: Mapper throws on non-numeric size
- **WHEN** the mapper processes an attachment with a `size` value that cannot be parsed as an integer
- **THEN** the mapper SHALL throw a typed mapping error

#### Scenario: Mapper preserves sizeName verbatim
- **WHEN** the mapper processes an attachment with `sizeName` = `"1.5 MB"`
- **THEN** `Attachment.sizeName` SHALL equal `"1.5 MB"` unchanged

#### Scenario: Mapper preserves encrypted key as-is
- **WHEN** the mapper processes an attachment with a `key` field
- **THEN** `Attachment.encryptedKey` SHALL equal the raw EncString from the server without modification
