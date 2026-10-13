# Client certificates

## Requirements
- Import exactly one currently valid client-auth PKCS#12 identity with a private key. Reject invalid KU/EKU, wrong password, malformed input and multiple identities without permanent import side effects.
- Preview subject/alias, issuer, validity and SHA-256 fingerprint; require explicit confirmation before saving. Clear import password and temporary bytes.
- Secrets live only in app-isolated, non-sync, device-only Keychain items. Local configuration contains display metadata, UUID and exact HTTPS origin only.
- Restore exact managed identity after restart. Missing/corrupt configuration fails visibly without alternate identity or fallback environment.
- Only the assigned HTTPS host and effective port receive the client identity. System server-trust validation remains enabled.
- External requests never select a client identity or send bearer tokens. Reject cross-origin redirects.
- Login, TOTP, refresh and sync use the server session. Configuration changes and sign-out cancel sessions; discard stale responses.
- Configurations without mTLS continue using existing API and vault logic. Attachments on mTLS servers are explicitly unavailable in this prototype.
