# Optional mTLS prototype (packages 0–3)

Support a single explicitly selected HTTPS origin for self-hosted Bitwarden/Vaultwarden. Import one PKCS#12 identity before login, retain it in the device-only macOS Keychain, and use an immutable per-server URLSession for prelogin, login, refresh and sync. Vault encryption is unchanged.

Non-goals: issuing/renewing certificates, arbitrary existing Keychain identities, endpoint origin overrides, SSO, hardware tokens, product release. Stop for joint acceptance after the prototype.
