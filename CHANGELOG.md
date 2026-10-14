# Changelog

## Unreleased

- Add verification codes: a login with a TOTP seed now shows its current one-time code and a
  countdown in the item, and a new "Codes" sidebar entry lists every item that has
  one. Supports base32 secrets and `otpauth://totp` links (SHA-1, SHA-256, SHA-512; 6 to 8 digits).
- **Changed**: "Copy Code" (⌃⌘C) now copies the current generated code instead of the raw TOTP
  seed, and the raw seed can no longer be copied.
- Fix a crash when locking the vault (including sleep and screen lock) by using
  the actual index ranges when zeroing sliced organization and vault key buffers.
