# Security

Prizm is a password manager. This document explains exactly how it protects your
data — what is encrypted, where keys live, what threats it defends against, and what
it does not. The goal is to let any developer or technically literate user audit the
implementation and decide whether to trust it. No black boxes.

---

## Reporting a Vulnerability

Please do **not** open a public GitHub issue for security vulnerabilities.

Report privately via GitHub's [Security Advisories](https://github.com/b0x42/prizm/security/advisories/new)
or email the maintainer directly (address in the GitHub profile). Include a description
of the issue, steps to reproduce, and any relevant log output or proof of concept.

---

## Encryption

### Data at rest

No vault data is ever written to disk in plaintext. The only sensitive material
persisted on disk is the **encrypted user key**, stored in the macOS Keychain under
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — accessible only when the Mac is
unlocked and only on this specific device, excluded from iCloud Keychain and backups.

| Data | How it is protected |
|------|---------------------|
| Vault items (passwords, card numbers, identities, notes, SSH keys, custom fields) | AES-256-CBC + HMAC-SHA256; decrypted in memory after unlock only, never written to disk |
| File attachments | Two-layer AES-256-CBC + HMAC-SHA256; plaintext exists in memory only during upload/download; see "File Attachments" section |
| Master password | Never stored anywhere; used transiently during KDF and then discarded |
| Encrypted user key (`encUserKey`) | AES-256-CBC encrypted by the stretched master key; stored in Keychain |
| Access and refresh tokens | Stored in Keychain under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| KDF parameters | Stored in Keychain; required for offline unlock |

### Data in transit

All API communication uses HTTPS/TLS. Vault data is **encrypted before it leaves the
device** — when creating or editing an item, the client encrypts the plaintext fields
using the vault symmetric keys and sends only ciphertext to the server. The server
never receives plaintext vault content or the master key at any point.

Authentication sends a one-way derived hash (`serverHash`) rather than the master
password itself.

### Algorithms

| Algorithm | Purpose | Implementation |
|-----------|---------|----------------|
| AES-256-CBC + PKCS7 | Vault item encryption / decryption | CommonCrypto (`kCCAlgorithmAES128`, 256-bit key) |
| AES-256-CBC (no PKCS7, Bitwarden binary blob) | File attachment blob encryption | CommonCrypto; blob format: IV(16) ‖ ciphertext ‖ HMAC(32) per Bitwarden Security Whitepaper §4 |
| HMAC-SHA256 | MAC verification (Encrypt-then-MAC) for both vault items and attachments | CryptoKit `HMAC<SHA256>` |
| PBKDF2-SHA256 | Master key derivation (PBKDF2 accounts) | CommonCrypto `CCKeyDerivationPBKDF` |
| Argon2id | Master key derivation (Argon2id accounts) | `Argon2Swift` — thin wrapper around the reference C implementation |
| HKDF-SHA256 | Key stretching | CryptoKit `HKDF<SHA256>` (RFC 5869) |

No hand-rolled cryptographic algorithms are used. All implementations are Apple system
frameworks or the vendored `Argon2Swift` package (Argon2id is not provided by Apple
frameworks).

---

## Key Management

### Where keys live

| Key material | Storage | Lifetime |
|---|---|---|
| Master key (32 bytes) | In-memory only | Derived on login/unlock; zeroed on lock or sign-out |
| Stretched keys (enc + mac, 64 bytes) | In-memory only | Derived from master key; zeroed on lock |
| Vault symmetric keys (enc + mac) | In-memory only | Decrypted from `encUserKey`; zeroed on lock |
| Encrypted user key (`encUserKey`) | macOS Keychain | Persisted across sessions; deleted on sign-out |
| Access token | macOS Keychain | Persisted across sessions; deleted on sign-out |
| Refresh token | macOS Keychain | Persisted across sessions; deleted on sign-out |
| KDF parameters | macOS Keychain | Persisted across sessions; deleted on sign-out |
| Device identifier (UUID) | macOS Keychain | Stable across sessions; deleted on sign-out |

### Key lifecycle

1. **Login** — master password + email → KDF (PBKDF2 or Argon2id) → master key →
   HKDF → stretched keys → decrypt `encUserKey` → vault symmetric keys. All in memory.
2. **Lock** — all in-memory key material is zeroed. Keychain entries are retained so
   the vault can be unlocked offline without re-authenticating to the server.
3. **Sign out** — all in-memory key material is zeroed and all Keychain entries for
   the account are deleted. The app returns to a blank login screen.

---

## File Attachments

Attachments use the Bitwarden two-layer client-side encryption scheme (Security Whitepaper §4).
No plaintext file content is ever sent to the server.

### Encryption scheme

Three encrypted artifacts are produced per attachment:

| Artifact | What it is | How it is encrypted |
|---|---|---|
| Encrypted file blob | The full file contents | AES-256-CBC + HMAC-SHA256 using the per-attachment key; binary layout: IV(16) ‖ ciphertext ‖ HMAC(32) |
| Encrypted attachment key | 64-byte random per-attachment key | EncString type-2 (AES-256-CBC + HMAC-SHA256) using the cipher key |
| Encrypted file name | The original file name | EncString type-2 (AES-256-CBC + HMAC-SHA256) using the cipher key |

The **cipher key** is either the vault symmetric key or a per-item key (if the cipher has
one). The **attachment key** is a freshly generated 64-byte random value for each upload.

### Key locations

| Key material | Storage | Lifetime |
|---|---|---|
| Per-attachment key (64 bytes) | In-memory only | Exists from the start of `upload()` until it returns; zeroed in `defer` |
| Cipher key (64 bytes) | In-memory only | Passed in from the calling use case; never persisted by the repository |
| Encrypted attachment key (EncString) | Bitwarden/Vaultwarden server | Stored as part of the cipher metadata; decrypted on demand during download |

### Temp file lifecycle (Open action)

When a user opens an attachment, the decrypted plaintext is written to a system temp
directory file and opened with the default application. The temp file is:

1. Overwritten with zeros then deleted after **30 seconds** (deadline-based cleanup).
2. Cleaned up on every **foreground transition** (`NSApplication.didBecomeActiveNotification`).

The 30-second window is a trade-off: long enough for the application to load the file,
short enough to limit plaintext exposure if the user switches away without closing the file.

### Upload-incomplete state

If a network failure occurs after the server creates attachment metadata but before the
encrypted blob is fully uploaded, the attachment is marked `isUploadIncomplete = true`.
The server retains the empty metadata record. The client shows a "Retry" action which:
1. Deletes the orphaned metadata record via `DELETE /api/ciphers/{id}/attachment/{attachmentId}`.
2. Performs a fresh upload as a new attachment.

### Threat model additions

- **Server sees only ciphertext** — attachment keys and file contents are encrypted
  before the first API call; the server never receives plaintext.
- **Per-attachment key isolation** — each file is encrypted with an independent 64-byte
  key; compromising one attachment key does not expose other attachments.
- **Temp file exposure window** — the plaintext is on disk for at most 30 seconds after
  opening. A disk image captured during this window could recover the file content.
  Full-disk encryption (FileVault) is strongly recommended.
- **Memory during upload/download** — raw file bytes are held in memory only for the
  duration of the operation, then zeroed. A memory dump during an active upload/download
  could reveal the plaintext.

---

## Threat Model

### What this app defends against

- **Server compromise** — The server never receives the master password, master key,
  or plaintext vault data. A fully compromised server exposes only ciphertext; an
  attacker must still brute-force the KDF to decrypt it.
- **Disk / at-rest compromise** — Vault data is never on disk in plaintext. The
  encrypted user key in the Keychain cannot be decrypted without the master password.
- **Memory dump after lock** — All key material is zeroed on lock. A memory dump
  taken after the vault locks reveals no usable keys.
- **Clipboard sniffing** — Copied secrets are automatically cleared from the clipboard
  after 30 seconds (best-effort on app quit).
- **Network eavesdropping** — All server communication uses HTTPS/TLS. Vault payloads
  are encrypted before transmission regardless.

### What this app does NOT protect against

- **Compromised macOS installation** — The app relies on macOS sandboxing, Keychain
  integrity, and process isolation. A rootkit or kernel exploit invalidates these
  guarantees.
- **Debugger or memory inspector while unlocked** — While the vault is unlocked, key
  material exists in process memory. An attacker with `task_for_pid` or debugger
  access can read it.
- **Keylogger** — The master password is entered via the keyboard. A keylogger can
  capture it before it reaches the app.
- **Physical access while the Mac is unlocked** — Keychain items with
  `WhenUnlockedThisDeviceOnly` are accessible to the app whenever the Mac is in an
  unlocked state.
- **TLS interception (MitM on server identity)** — Certificate pinning is not
  implemented. TLS validation relies on the system trust store.
- **Organisation vaults** — Only personal vault ciphers are decrypted. Organisation
  ciphers are skipped.

---

## Runtime Protections

The app is built with App Sandbox and Hardened Runtime enabled:

- Outbound network connections: allowed (Bitwarden/Vaultwarden API, icon service)
- Inbound network connections: denied
- File system access: read-only, user-selected files only
- No access to camera, microphone, contacts, calendars, location, Bluetooth, USB, or printing

---

## Standards and References

- [Bitwarden Security Whitepaper](https://bitwarden.com/help/bitwarden-security-white-paper/) — vault architecture, key derivation, encryption flow, attachment encryption (§4)
- [RFC 5869](https://tools.ietf.org/html/rfc5869) — HKDF
- [RFC 8018](https://tools.ietf.org/html/rfc8018) / [NIST SP 800-132](https://csrc.nist.gov/publications/detail/sp/800-132/final) — PBKDF2
- [RFC 9106](https://tools.ietf.org/html/rfc9106) — Argon2id
- [NIST SP 800-107](https://csrc.nist.gov/publications/detail/sp/800-107/rev-1/final) — HMAC
