## Why

The vault edit flow has no way to generate strong passwords or passphrases, forcing users to leave the app to create credentials. This is the core building block for "register for a new service" — without it, the create-new-item feature is incomplete.

## What Changes

- Introduce a `PasswordGenerator` utility in the Domain layer (pure Swift, no I/O) supporting two modes: random character passwords and word-based passphrases.
- Add a generator popover to `LoginEditForm` anchored to the password field, and to `SSHKeyEditForm` anchored to the private key field.
- The popover shows a live-updating preview, all configuration controls, a one-click copy, and a one-click "Use Password" / "Use Passphrase" action that writes the value into the bound field.
- No API changes. No new use cases. No Keychain changes. Generator settings are persisted to `UserDefaults` as UI preferences (not vault data).

## Capabilities

### New Capabilities

- `password-generator`: Password and passphrase generation with full configuration — random mode (length 5–128, uppercase, lowercase, digits, symbols, avoid-ambiguous toggles) and passphrase mode (word count 3–10, separator, capitalize, include-number toggles). Accessible from the password field in Login edit and private key field in SSH Key edit.

### Modified Capabilities

- `vault-item-edit`: The Login edit sheet and SSH Key edit sheet gain a generator trigger button on sensitive fields. No requirement changes — this is an additive enhancement to the existing edit form capability.

## Impact

- **New**: `Domain/Utilities/RandomnessProvider.swift` — protocol with a single `randomBytes(count:)` method; keeps Domain free of Security.framework.
- **New**: `Data/Crypto/CryptographicRandomnessProvider.swift` — `RandomnessProvider` implementation backed by `SecRandomCopyBytes`.
- **New**: `Domain/Utilities/PasswordGenerator.swift` — pure Swift generator, imports Foundation only; receives `RandomnessProvider` via injection.
- **New**: `Presentation/Vault/Edit/PasswordGeneratorView.swift` — SwiftUI popover.
- **New**: `Presentation/Vault/Edit/PasswordGeneratorViewModel.swift` — `@MainActor ObservableObject` owning generator state.
- **Modified**: `Presentation/Vault/Edit/LoginEditForm.swift` — generator button on password field.
- **Modified**: `Presentation/Vault/Edit/SSHKeyEditForm.swift` — generator button on private key field.
- **Modified**: `Presentation/Vault/Edit/EditFieldRow.swift` — optional generator button slot.
- **New tests**: `MacwardenTests/PasswordGeneratorTests.swift` — unit tests covering character-set composition, length bounds, ambiguous-char exclusion, passphrase word count, separator injection, entropy lower bound.
- **New tests**: `MacwardenTests/PasswordGeneratorViewModelTests.swift` — unit tests covering config-change regeneration, clipboard copy, UserDefaults persistence, and default-settings restoration on first launch.
- **No breaking changes.**
