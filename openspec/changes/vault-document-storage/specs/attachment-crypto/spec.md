## ADDED Requirements

### Requirement: Per-attachment key generation
The system SHALL generate a cryptographically random 64-byte attachment key for each new attachment (32-byte encryption key ‖ 32-byte MAC key) using `SecRandomCopyBytes`. This key SHALL be generated in the Data layer and SHALL NOT be reused across attachments.

#### Scenario: Each attachment gets a unique key
- **WHEN** two attachments are stored in the same vault item
- **THEN** each SHALL have a distinct 64-byte attachment key — no two attachment keys SHALL be equal

#### Scenario: Key material comes from a secure random source
- **WHEN** an attachment key is generated
- **THEN** it SHALL be produced via `SecRandomCopyBytes` (Security.framework), not via `arc4random` or `Int.random`

---

### Requirement: File data encrypted with attachment key
The system SHALL encrypt attachment file data using AES-256-CBC + HMAC-SHA256 (EncString type 2) with the per-attachment key. The encrypted output SHALL use the standard EncString binary layout: 16-byte IV ‖ ciphertext ‖ 32-byte HMAC. MAC SHALL be verified before decryption (Encrypt-then-MAC).

#### Scenario: File data is not stored or transmitted in plaintext
- **WHEN** an attachment is prepared for upload
- **THEN** the bytes written to the upload stream SHALL be the AES-256-CBC ciphertext, not the original file data

#### Scenario: MAC verification prevents tampered ciphertext from decrypting
- **WHEN** any byte of the encrypted blob is modified and decryption is attempted
- **THEN** the system SHALL throw a MAC verification error and SHALL NOT return any plaintext bytes

#### Scenario: Round-trip encrypt then decrypt returns original bytes
- **WHEN** a file is encrypted with an attachment key and then decrypted with the same key
- **THEN** the decrypted bytes SHALL be identical to the original file bytes

---

### Requirement: Attachment key encrypted with cipher key
The system SHALL encrypt the 64-byte attachment key with the cipher's symmetric key (or the user's vault symmetric key if the cipher has no per-item key) using AES-256-CBC + HMAC-SHA256, producing an EncString. This encrypted attachment key SHALL be stored in the attachment metadata on the server.

#### Scenario: Encrypted attachment key is stored as EncString type 2
- **WHEN** an attachment key is wrapped for upload
- **THEN** the result SHALL be an EncString in `2.<iv_b64>|<ct_b64>|<mac_b64>` format

#### Scenario: Attachment key can be recovered from encrypted form using cipher key
- **WHEN** the encrypted attachment key is decrypted with the correct cipher key
- **THEN** the result SHALL be the original 64-byte attachment key

---

### Requirement: Attachment key material is zeroed after use
The system SHALL zero the in-memory attachment key and decrypted file data buffers as soon as they are no longer needed (after encryption completes, or after the decrypted bytes are written to disk/opened). Swift `Data` buffers containing key material SHALL be zeroed using `withUnsafeMutableBytes` before release.

#### Scenario: Attachment key is zeroed after upload completes
- **WHEN** the encrypted file data has been successfully uploaded
- **THEN** the plaintext attachment key bytes SHALL be overwritten with zeroes in memory

#### Scenario: Decrypted file data is zeroed after write
- **WHEN** the decrypted file bytes have been written to a temp file or user-chosen path
- **THEN** the in-memory `Data` buffer SHALL be zeroed before it is released
