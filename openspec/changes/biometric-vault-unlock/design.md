## Context

The current unlock flow requires the user to type their master password every time the vault locks. The password is fed into a slow KDF (Argon2id or PBKDF2 — deliberately 0.5–2 s) to re-derive the vault symmetric key (`CryptoKeys`). The result is then passed to `PrizmCryptoService.unlockWith(keys:)`.

macOS provides `LocalAuthentication` and Secure Enclave-backed Keychain access controls, which allow a Keychain item to be gated by a successful biometric evaluation. We can store the already-derived `CryptoKeys` behind that gate. When the user re-authenticates with Touch ID, we read the keys and call `unlockWith(keys:)` directly — skipping the KDF entirely.

All existing Keychain items use `kSecAttrAccessible`, which is incompatible with `kSecAccessControl`. The two cannot be set on the same item. A new storage path is required.

## Goals / Non-Goals

**Goals:**
- Touch ID unlock that is fast (no KDF), secure (Secure Enclave gate), and degradable (password always available)
- Auto-prompt biometrics immediately when the lock screen appears
- First-time enrollment prompt after successful password unlock; re-enrollment prompt after biometric invalidation
- Settings toggle to enable / disable at any time
- Platform-agnostic code naming so iOS Face ID requires no renaming

**Non-Goals:**
- Biometric login (first-time authentication against the server — password required)
- Windows Hello or other non-Apple biometrics
- Automatic lock timer or lock-on-idle (separate change)
- Syncing the biometric preference across devices

## Decisions

### 1. Store `CryptoKeys`, not the master password

**Decision**: The biometric Keychain item holds the serialised `CryptoKeys` (64 bytes: 32-byte encryption key + 32-byte MAC key).

**Rationale**: Storing the master password and re-running the KDF on each biometric unlock would still be slow and would persist the user's password in Keychain indefinitely. `CryptoKeys` are the actual secret needed by `PrizmCryptoService.unlockWith(keys:)`. Gating 64 bytes of key material behind the Secure Enclave is the same model used by Bitwarden's official clients and 1Password.

**Alternative rejected**: Store master password → re-derive on Touch ID. Slow, and needlessly exposes the password.

---

### 2. `.biometryCurrentSet` access control flag

**Decision**: Use `SecAccessControlCreateWithFlags` with `.biometryCurrentSet`. `kSecAttrSynchronizable` is not set on the biometric Keychain item — it remains device-only and is never backed up or synced to iCloud, satisfying Constitution Security Requirement property (1).

**Rationale**: `.biometryCurrentSet` invalidates the Keychain item if the user adds or removes a fingerprint. This means a newly enrolled fingerprint cannot silently access an existing vault. `.biometryAny` is weaker — it would allow any fingerprint enrolled after the user opted in to unlock the vault without their knowledge.

**On "UserKey MUST NOT be exported" (Bitwarden normative)**: Storing `CryptoKeys` in a biometric-protected Keychain item is on-device protected storage, not an export. The key never crosses a process boundary, a device boundary, or a network boundary. It is gated by the Secure Enclave and the user's enrolled biometrics. This satisfies the Bitwarden requirement's intent — preventing key escrow and ambient-authority decryption — while enabling biometric unlock.

**Alternative rejected**: `.biometryAny` — convenient but grants implicit access to newly added biometrics.

---

### 3. Separate `BiometricKeychainService` protocol (not extending `KeychainService`)

**Decision**: Introduce a new `BiometricKeychainService` protocol with `writeBiometric(data:key:)` and `readBiometric(key:)` methods, implemented by a new `BiometricKeychainServiceImpl`.

**Rationale**: `kSecAccessControl` and `kSecAttrAccessible` are mutually exclusive — the same `SecItem` cannot carry both. Mixing them into `KeychainServiceImpl` would require conditional branching throughout `write(data:key:)` and `read(key:)`, making the existing contract unclear. A dedicated service has a focused surface and can evolve independently (e.g. adding `LAContext` reuse, fallback policy).

**Alternative rejected**: Add `writeBiometric` / `readBiometric` overloads to `KeychainService` protocol. Possible but pollutes the protocol with an orthogonal concern.

---

### 4. Auto-prompt via `.task` on `UnlockView` appearance

**Decision**: `UnlockViewModel` exposes a `triggerBiometricUnlockIfAvailable()` method. `UnlockView` calls it from `.task {}` (not `.onAppear {}`) so the prompt fires asynchronously after the view renders, avoiding a UI freeze on the lock screen.

**Rationale**: `.task {}` runs after layout; `.onAppear {}` fires synchronously and can block the render. The biometric prompt must not block the UI thread — if it did, the lock screen would appear frozen until the system prompt resolves.

---

### 5. `biometricUnlockEnabled` in `UserDefaults`; source of truth is Keychain item existence

**Decision**: `UserDefaults.biometricUnlockEnabled` is used only as a UI hint (show/hide Touch ID button). The authoritative check before attempting biometric unlock is `BiometricKeychainService.readBiometric(key:)` — if the item is gone (invalidated or deleted), the attempt fails gracefully.

**Rationale**: A UserDefaults flag alone can get out of sync with the Keychain (e.g. app reinstall, manual Keychain clear). Treating the Keychain as source of truth means the UI may show the Touch ID button but the attempt simply fails with an `.itemNotFound` error, which is handled by falling back to password and clearing the flag.

**One-time enrollment prompt**: A second UserDefaults flag, `biometricEnrollmentPromptShown`, tracks whether the enrollment prompt has ever been shown. It is set to `true` after the prompt is presented — regardless of whether the user taps "Enable" or "Not now" — and is never reset under normal conditions. This means the prompt fires exactly once in the lifetime of the app install. After dismissal in either direction, the Settings toggle is the only way to enable biometric unlock. The prompt copy informs the user of this: *"You can also enable this in Settings at any time."*

**Re-enrollment after invalidation**: If `.biometryCurrentSet` invalidation is detected, `biometricEnrollmentPromptShown` is reset to `false` alongside clearing `biometricUnlockEnabled` and the Keychain item. This causes the prompt to fire again after the next successful password unlock, but with different copy explaining why re-enrollment is needed: *"Your Touch ID settings changed — a fingerprint was added or removed. For your security, Prizm disabled Touch ID unlock."* The `BiometricEnrollmentPromptView` accepts a `reason` parameter (`.firstTime` / `.reenrollAfterInvalidation`) to switch copy accordingly.

**Alternative rejected**: Session-scoped in-memory flag — would re-show the prompt on every app launch until the user opts in, which becomes repetitive.

---

### 6. Platform-agnostic naming, macOS UI label from `LAContext.biometryType`

**Decision**: All code identifiers use `Biometric*` / `biometric*`. `UnlockView` reads `LAContext().biometryType` at render time to show "Touch ID" (`.touchID`), "Face ID" (`.faceID`), or a generic "Biometric unlock" fallback.

## Risks / Trade-offs

**Risk: Keychain item unavailable on first debug build after Team ID change**
→ The biometric Keychain item is scoped to `kSecUseDataProtectionKeychain: true`. A Team ID change invalidates the access group, making the item unreadable. Graceful fallback to password + clear the flag handles this silently.

**Risk: `LAError.biometryLockout` (too many failed attempts)**
→ After several consecutive Touch ID failures, macOS locks biometrics and requires the device passcode. `LAContext.evaluatePolicy` returns `LAError.biometryLockout`. Surface this to the user ("Too many failed attempts — use your master password") and fall back to the password screen.

**Risk: App Sandbox + `kSecAccessControl` + `kSecUseDataProtectionKeychain` interaction**
→ On macOS, `kSecAccessControl` with `.biometryCurrentSet` has been validated to work in sandboxed apps with `kSecUseDataProtectionKeychain: true`. The access group is inferred from the `keychain-access-groups` entitlement. No additional entitlement is required for `LocalAuthentication` biometrics on macOS.

**Risk: `CryptoKeys` serialisation format**
→ `CryptoKeys` contains two `Data` fields. We serialise as `encryptionKey (32 bytes) || macKey (32 bytes)` — a fixed 64-byte blob. No JSON or Codable overhead; deserialization is a simple split at byte 32. If `CryptoKeys` gains fields in a future refactor, the serialisation format must be versioned.

## Open Questions

- Does Prizm already have a Settings screen? If not, the biometric toggle requires one to be created. The proposal assumes a settings panel — confirm scope before implementation.
