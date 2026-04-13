## ADDED Requirements

### Requirement: RSA private key is decrypted at unlock time
The system SHALL decrypt the user's RSA private key (`profile.privateKey` EncString) using the vault symmetric key immediately after vault unlock. The decrypted RSA private key SHALL be held in-memory by `PrizmCryptoService` alongside the vault symmetric key and cleared on vault lock. The private key bytes SHALL NOT be logged.

#### Scenario: RSA private key available after unlock
- **WHEN** the vault is unlocked with a valid master password or biometrics
- **THEN** the decrypted RSA private key SHALL be available in-memory for org key unwrap operations

#### Scenario: RSA private key cleared on lock
- **WHEN** the vault is locked
- **THEN** the RSA private key SHALL be cleared from memory alongside the vault symmetric key

#### Scenario: Missing privateKey field handled gracefully
- **GIVEN** the sync profile contains no `privateKey` field (Vaultwarden instance with no org membership)
- **WHEN** the vault is unlocked
- **THEN** no error is raised and org key unwrap simply has no key to work with

---

### Requirement: Organization symmetric keys are unwrapped at sync time
For each organization returned in the sync response, the system SHALL unwrap the organization's symmetric key using RSA-OAEP-SHA1 and the user's in-memory RSA private key. Unwrapped org keys SHALL be stored in `OrgKeyCache` keyed by `organizationId`. Algorithm: `SecKeyCreateDecryptedData` with `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` (`Security.framework`). No new dependencies are introduced.

#### Scenario: Org key unwrapped and cached at sync
- **WHEN** a sync response containing one or more organizations is processed
- **THEN** each organization's symmetric key SHALL be unwrapped and stored in `OrgKeyCache`

#### Scenario: Failed org key unwrap is logged and skipped
- **GIVEN** an organization's key EncString is malformed or the RSA operation fails
- **WHEN** sync processes that organization
- **THEN** a `.fault` log entry SHALL be emitted and that org's ciphers SHALL be skipped (treated as if `organisationCipherSkipped`)

#### Scenario: OrgKeyCache cleared on vault lock
- **WHEN** the vault is locked
- **THEN** `OrgKeyCache` SHALL be cleared alongside `VaultKeyCache`

---

### Requirement: Org ciphers are decrypted using the organization key
The system SHALL decrypt org ciphers (`organizationId != nil`) using the org's symmetric key from `OrgKeyCache` rather than the user's vault key. `CipherMapper` SHALL look up the org key by `organizationId` and use it in place of the personal vault `CryptoKeys`. Per-item cipher key wrapping (existing `raw.key` path) SHALL continue to work — the per-item key is decrypted with the org key instead of the vault key.

#### Scenario: Org cipher decrypted with org key
- **GIVEN** a cipher with a non-nil `organizationId` and the org key is in `OrgKeyCache`
- **WHEN** `CipherMapper.map` is called
- **THEN** the cipher's name and all fields SHALL be decrypted using the org's `CryptoKeys`

#### Scenario: Org cipher with per-item key
- **GIVEN** a cipher with a non-nil `organizationId` and a non-nil `raw.key`
- **WHEN** `CipherMapper.map` is called
- **THEN** the per-item key SHALL be decrypted using the org key, and cipher fields decrypted using the per-item key

#### Scenario: Org cipher skipped when org key missing
- **GIVEN** a cipher with `organizationId` that has no matching entry in `OrgKeyCache`
- **WHEN** `CipherMapper.map` is called
- **THEN** `CipherMapperError.organisationCipherSkipped` SHALL be thrown and the cipher omitted from vault items
