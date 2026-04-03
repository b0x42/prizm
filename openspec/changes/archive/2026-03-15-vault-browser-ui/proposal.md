## Why

There is no native macOS client for self-hosted Bitwarden or Vaultwarden. Users who run their own vault server must rely on browser extensions or the Bitwarden desktop app, which is Electron-based. A native SwiftUI client provides a faster, lighter-weight experience that feels at home on macOS, while keeping all cryptography local and auditable.

## What Changes

This is the initial release of Prizm — a native macOS Bitwarden/Vaultwarden client built entirely with SwiftUI and Apple frameworks.

- **Account Login**: User enters a self-hosted server URL, email, and master password. TOTP two-factor authentication is supported.
- **Vault Unlock**: Returning users enter their master password on an unlock screen; the vault decrypts locally without a network request.
- **Three-Pane Vault Browser**: A `NavigationSplitView` presents a sidebar (categories + counts), a middle item list, and a detail pane showing all fields for the selected item.
- **All item types displayed**: Login, Card, Identity, Secure Note, and SSH Key. Secret fields (passwords, card numbers, private keys) are masked by default with a reveal toggle.
- **Clipboard auto-clear**: Copied secrets are automatically cleared from the clipboard after 30 seconds.
- **Real-time search**: Filters the item list within the active category on every keystroke.
- **Favicon support**: Item icons fetched from the configured Bitwarden icon service with in-memory and disk caching.

## Capabilities

### New Capabilities

- `vault-browser-ui`: Core vault browser — login, unlock, three-pane item browsing, per-type detail views, search, clipboard management, favicon fetching.

### Modified Capabilities

<!-- This is the initial version — no existing capabilities modified -->

## Impact

- **Domain**: Full entity model (`VaultItem`, `Account`, `ServerEnvironment`, `KdfParams`, `CustomField`, `SidebarSelection`) and all use-case protocols (`LoginUseCase`, `UnlockUseCase`, `SyncUseCase`, `SearchVaultUseCase`).
- **Data**: Native Bitwarden crypto (`BitwardenCryptoServiceImpl` actor using CommonCrypto + CryptoKit + Argon2Swift), `PrizmAPIClient` (URLSession), `VaultRepositoryImpl`, `CipherMapper`, `KeychainService`, `FaviconLoader`.
- **Presentation**: `LoginView`, `UnlockView`, `SyncProgressView`, `VaultBrowserView`, `SidebarView`, `ItemListView`, per-type detail views, `MaskedFieldView`, `FieldRowView`, `FaviconView`, `DesignSystem`.
- **No third-party dependencies** beyond vendored `Argon2Swift` (for Argon2id KDF) — all crypto via Apple frameworks.
