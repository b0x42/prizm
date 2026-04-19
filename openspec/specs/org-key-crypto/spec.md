## ADDED Requirements

### Requirement: RSA private key is decrypted at sync time
The system SHALL decrypt the user's RSA private key (`profile.privateKey` EncString) using the vault symmetric key during `SyncRepositoryImpl.sync()`, when the sync response contains a non-empty `organizations` array and a non-nil `profile.privateKey`. The decrypted RSA private key is used immediately within the same sync call to unwrap org keys and is not retained beyond that scope. Zeroing and clearing on vault lock applies to `OrgKeyCache` (which holds the unwrapped org keys). The private key bytes SHALL NOT be logged.

> **Implementation note:** The original spec said "at unlock time" but the implementation decrypts the RSA private key during sync (where the EncString is available in the sync profile). The key is used transiently within `sync()` — it is not stored as long-lived actor state.

#### Scenario: RSA private key decrypted during sync
- **WHEN** sync completes and the profile contains a `privateKey` EncString and at least one organization
- **THEN** the RSA private key SHALL be decrypted and used to unwrap org symmetric keys within that sync call

#### Scenario: RSA private key not retained after sync
- **WHEN** `sync()` returns
- **THEN** the raw RSA private key bytes SHALL not be held in any long-lived actor state

#### Scenario: Missing privateKey field handled gracefully
- **GIVEN** the sync profile contains no `privateKey` field (Vaultwarden instance with no org membership)
- **WHEN** sync runs
- **THEN** the org key unwrap block is skipped entirely with no error raised

---

### Requirement: Organization symmetric keys are unwrapped at sync time
For each organization returned in the sync response, the system SHALL unwrap the organization's symmetric key using RSA-OAEP-SHA1 and the user's in-memory RSA private key. Unwrapped org keys SHALL be stored in `OrgKeyCache` keyed by `organizationId`. Org key material SHALL be zeroed on removal from the cache (Constitution §III). Algorithm: `SecKeyCreateDecryptedData` with `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` (`Security.framework`). No new dependencies are introduced.

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
