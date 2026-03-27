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
The system SHALL encrypt attachment file data using the AES-256-CBC + HMAC-SHA256 algorithm with the per-attachment key. The encrypted output SHALL be transmitted as **raw binary** — NOT as a Base64-encoded EncString string — with layout: 16-byte IV ‖ ciphertext ‖ 32-byte HMAC. This is the same algorithm as EncString type 2 but a different wire format: EncString (Base64-encoded, `2.<iv>|<ct>|<mac>`) is used only for metadata fields (attachment key and file name); the file blob is always raw bytes. MAC SHALL be verified before decryption (Encrypt-then-MAC).

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

### Requirement: Known-answer tests against published vectors
The attachment crypto implementation SHALL include known-answer tests (KATs) validating the AES-256-CBC + HMAC-SHA256 scheme against published test vectors. Per §IV of the Constitution, KATs are mandatory for all crypto implementations. The following sources SHALL be used:
- AES-CBC: NIST SP 800-38A test vectors (CBC-AES256)
- HMAC-SHA256: RFC 4231 test vectors
- Full EncString round-trip: Bitwarden Security Whitepaper test vectors if published; otherwise use a vector derived from the official Bitwarden iOS client test suite

#### Scenario: AES-CBC encryption matches NIST SP 800-38A vector
- **WHEN** the encrypt function is called with a known key, IV, and plaintext from NIST SP 800-38A
- **THEN** the output ciphertext SHALL exactly match the published expected value

#### Scenario: HMAC-SHA256 matches RFC 4231 vector
- **WHEN** HMAC-SHA256 is computed over a known key and message from RFC 4231
- **THEN** the output MAC SHALL exactly match the published expected value

#### Scenario: EncString round-trip KAT
- **WHEN** a known plaintext blob is encrypted then decrypted with a fixed key
- **THEN** the decrypted output SHALL be byte-for-byte identical to the original and SHALL match the expected ciphertext from a reference implementation

---

### Requirement: Attachment key material is zeroed after use
The system SHALL zero the in-memory attachment key and decrypted file data buffers as soon as they are no longer needed (after encryption completes, or after the decrypted bytes are written to disk/opened). Swift `Data` buffers containing key material SHALL be zeroed using `withUnsafeMutableBytes` before release.

#### Scenario: Attachment key is zeroed after upload completes
- **WHEN** the encrypted file data has been successfully uploaded
- **THEN** the plaintext attachment key bytes SHALL be overwritten with zeroes in memory

#### Scenario: Decrypted file data is zeroed after write
- **WHEN** the decrypted file bytes have been written to a temp file or user-chosen path
- **THEN** the in-memory `Data` buffer SHALL be zeroed before it is released
