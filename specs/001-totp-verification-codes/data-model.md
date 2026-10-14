# Data Model: TOTP Verification Codes

No persisted data is added. Everything below is in-memory and short-lived. Types are `nonisolated` value types in the Domain layer unless noted.

## TOTPHashAlgorithm

`enum`: `sha1`, `sha256`, `sha512`. Names the HMAC hash. Mapped to CryptoKit only inside the Data layer.

## TOTPConfiguration

Parsed form of a stored seed.

| Field | Type | Rule |
|---|---|---|
| `secret` | `Data` | Decoded base32 bytes. Must be non-empty. |
| `algorithm` | `TOTPHashAlgorithm` | Default `sha1`. |
| `digits` | `Int` | 6 to 8. Default 6. |
| `period` | `Int` (seconds) | Greater than 0. Default 30. |

Built only by `TOTPSeedParser.parse(_:)`, which throws `TOTPError` for anything else. Not cached: parsed per refresh pass and dropped, so no extra copy of the secret outlives the pass.

## TOTPCode

What the UI shows. Never stored.

| Field | Type | Rule |
|---|---|---|
| `digits` | `String` | Exactly `configuration.digits` characters, zero-padded. |
| `period` | `Int` | Seconds, copied from the configuration. |
| `secondsRemaining` | `Int` | 1 to `period`, computed from the clock. |

Derived values:

- `grouped`: six digits as "123 456". Other lengths split in the middle (8 digits as "1234 5678", 7 as "123 4567").
- `copyValue`: `digits` with no spaces.
- `isExpiringSoon`: `secondsRemaining <= 5`.

## TOTPError

`enum: Error, Equatable`:

| Case | Meaning |
|---|---|
| `emptySeed` | Seed is empty or whitespace. |
| `invalidSecret` | Not valid base32, or decodes to zero bytes. |
| `unsupportedScheme` | `steam://`, `otpauth://hotp`, or another scheme. |
| `unsupportedParameter` | Unknown algorithm, digits outside 6 to 8, or non-positive period. |

The UI maps every case to the same user-facing "unavailable" message, and never includes the seed in any message or log.

## SidebarSelection (modified)

New case `verificationCodes`.

- `displayName`: "Verification Codes"
- Equality: equal only to itself.
- Hash: a new distinct discriminator.

## TOTPCodeState (Presentation)

Per-item state published by `TOTPCodesViewModel`.

| Case | Meaning |
|---|---|
| `code(TOTPCode)` | A current code. |
| `unavailable` | The seed could not be used. |

`TOTPCodesViewModel.states: [String: TOTPCodeState]`, keyed by item id. Cleared (set to `[:]`) when tracking stops.

## Relationships and lifecycle

```text
VaultItem (login.totp: String?)
   │  read at refresh time, in memory only
   ▼
TOTPSeedParser ──▶ TOTPConfiguration ──▶ GenerateTOTPCodeUseCase ──▶ TOTPCode
                                                 │ uses
                                                 ▼
                                    PrizmCryptoService.hmac(...)
```

State transitions for one tracked item:

```text
not tracked ──start──▶ code ⇄ code (every second; new digits when the period rolls over)
                  └──▶ unavailable (seed invalid; stays until the item changes)
any state ──stop (view gone / scene inactive / vault locked)──▶ not tracked (state removed)
```

## Index membership (VaultRepositoryImpl)

An item is in the `.verificationCodes` index when all hold:

1. Not deleted (`isDeleted == false`).
2. Content is a Login.
3. `totp` is non-nil and not blank after trimming whitespace.

Sorted by name, case-insensitive. The sidebar count equals the index size, including items that will display "unavailable".
