# Security Model — Macwarden Client

This document describes, in plain language, the security architecture of this
Macwarden desktop client. It is intended to allow any developer or
technically literate user to verify the implementation (Constitution §VII).

---

## What Data Is Encrypted

| Data | Encryption | Notes |
|------|-----------|-------|
| Vault items (passwords, card numbers, identities, notes, SSH keys, custom fields) | AES-CBC-256 with HMAC-SHA256 (Encrypt-then-MAC) | Decrypted only in memory after unlock; never persisted in plaintext |
| Master password | Never stored anywhere | Only used transiently during KDF derivation |
| Encrypted user key (`encUserKey`) | AES-CBC-256 (encrypted by the stretched master key) | Stored in Keychain; decrypted at unlock time to obtain vault keys |
| Access / refresh tokens | Plaintext in Keychain | Protected by macOS Keychain ACL (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |

### Encryption Algorithms Used

- **AES-256-CBC** with PKCS7 padding — via CommonCrypto (`kCCAlgorithmAES128` with 256-bit key)
- **HMAC-SHA256** — via CryptoKit (`HMAC<SHA256>`) for MAC verification (Encrypt-then-MAC)
- **PBKDF2-SHA256** — via CommonCrypto (`CCKeyDerivationPBKDF`) for master key derivation
- **Argon2id** — via `Argon2Swift` (vendored reference C implementation) for Argon2id KDF
- **HKDF-SHA256** — via CryptoKit (`HKDF<SHA256>`) for key stretching (RFC 5869)
- **RSA-OAEP** with SHA-1 — via Security.framework for organisation key decryption (v2 scope)

All implementations use Apple system frameworks or the Argon2Swift vendored
package. No hand-rolled cryptographic algorithms are used (Constitution §III).

---

## Where Keys Are Stored

| Key Material | Storage | Access Conditions |
|-------------|---------|-------------------|
| Master key (32 bytes) | In-memory only | Derived on login/unlock; zeroed on lock/sign-out |
| Stretched keys (enc + mac, 64 bytes) | In-memory only | Derived from master key; zeroed on lock |
| Vault symmetric keys (enc + mac) | In-memory only | Decrypted from `encUserKey`; zeroed on lock |
| Encrypted user key (`encUserKey`) | macOS Keychain | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — accessible only while the Mac is unlocked and only on this device; not included in iCloud Keychain or backups |
| Access token | macOS Keychain | Same ACL as above |
| Refresh token | macOS Keychain | Same ACL as above |
| KDF parameters (type, iterations, memory, parallelism) | macOS Keychain | Same ACL — needed for offline unlock |
| Device identifier (UUID) | macOS Keychain | Same ACL — stable across sessions |

### Key Lifecycle

1. **Login**: Master password + email → KDF → master key → HKDF → stretched keys → decrypt `encUserKey` → vault keys. Vault keys remain in memory.
2. **Lock** (app quit or explicit lock): All in-memory key material is zeroed. Keychain data is retained for next unlock.
3. **Sign out**: All in-memory key material is zeroed AND all per-user Keychain entries are deleted. The user must re-authenticate to use the app.

---

## Threat Model

### What This App Defends Against

- **Server compromise**: The server never receives the master password or master key. Only a one-way hash (`serverHash`) is sent during authentication. Even if the server is fully compromised, the attacker cannot derive the master password without brute-forcing the KDF.
- **Disk/at-rest compromise**: Vault data is never stored on disk in plaintext. Only the encrypted user key is persisted, protected by the macOS Keychain with device-only access restrictions.
- **Memory dump after lock**: On lock, all key material is zeroed. A memory dump after lock reveals no vault keys.
- **Clipboard sniffing**: Copied secrets are auto-cleared from the clipboard after 30 seconds (best-effort).
- **Network eavesdropping**: All API communication uses HTTPS/TLS.

### What This App Does NOT Protect Against (Explicit Non-Goals)

- **Compromised macOS installation**: If the operating system itself is compromised (rootkit, kernel exploit), all bets are off. The app depends on macOS sandboxing, Keychain integrity, and process isolation being intact.
- **Running debugger / memory inspector while unlocked**: While the vault is unlocked, key material exists in process memory. An attacker with `task_for_pid` or debugger access can read it.
- **Keylogger capturing the master password**: The master password is typed by the user. A keylogger can capture it.
- **Physical access while the Mac is unlocked**: Keychain items with `WhenUnlockedThisDeviceOnly` are accessible to the app while the Mac is in an unlocked state.
- **Bitwarden server authentication (MitM on server identity)**: v1 does not implement certificate pinning.
- **Organisation cipher decryption**: v1 only decrypts personal vault ciphers. Organisation ciphers are silently skipped.
- **Write operations**: v1 is read-only. No create, edit, delete, or favourite-toggle operations.

---

## App Sandbox & Hardened Runtime

The app is built with:
- **App Sandbox** enabled (entitlements file)
- **Hardened Runtime** enabled
- Outbound network connections: allowed (for Bitwarden API + icon service)
- Inbound network connections: denied
- File system access: read-only user-selected files
- No access to: camera, microphone, contacts, calendars, location, Bluetooth, USB, printing

---

## Standards Referenced

- [Bitwarden Security Whitepaper](https://bitwarden.com/help/bitwarden-security-white-paper/) — vault architecture, key derivation, encryption flow
- [RFC 5869](https://tools.ietf.org/html/rfc5869) — HKDF (HMAC-based Key Derivation Function)
- [RFC 8018 / NIST SP 800-132](https://tools.ietf.org/html/rfc8018) — PBKDF2
- [RFC 9106](https://tools.ietf.org/html/rfc9106) — Argon2id
- [NIST SP 800-107](https://csrc.nist.gov/publications/detail/sp/800-107/rev-1/final) — HMAC recommendations
