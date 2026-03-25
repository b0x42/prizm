# Macwarden

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org/)
[![macOS](https://img.shields.io/badge/macOS-26%2B-blue.svg)](https://www.apple.com/macos/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4-purple.svg)](https://developer.apple.com/swiftui/)

A native Bitwarden client for macOS. Connect to your self-hosted [Bitwarden](https://bitwarden.com/) or [Vaultwarden](https://github.com/dani-garcia/vaultwarden) server and browse and edit your vault in a fast, lightweight desktop app.

## Screenshots

*Coming soon*

## Features

- **Connect to your server** — works with any self-hosted Bitwarden or Vaultwarden instance
- **Browse everything** — Logins, Cards, Identities, Secure Notes, and SSH Keys
- **Create items** — add new Logins, Cards, Identities, Secure Notes, and SSH Keys directly from the vault browser; items sync to your server immediately
- **Edit items** — update fields, names, notes, custom fields, and website URIs; changes sync back to your server
- **Manage website URIs** — add, remove, and reorder URIs on Login items with inline match-type configuration
- **Delete and restore** — move items to Trash, restore accidental deletions, or permanently delete individual items
- **Find items fast** — real-time search across names, usernames, URIs, and more
- **Native macOS** — built with SwiftUI, feels right at home

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New Login item |
| ⌘E | Edit selected item |
| ⌘S | Save edits |
| ⇧⌘Q | Sign out |
| ⌥ (hold) | Peek at masked passwords and secrets |
| ↑ ↓ | Navigate item list |
| ⇥ | Move between panes |
| ↩ | Submit (login, unlock, TOTP) |

## Security

All cryptography runs locally on your device:

- Master password never leaves your machine
- PBKDF2-SHA256 and Argon2id key derivation
- AES-256-CBC + HMAC-SHA256 authenticated encryption
- Session data stored in macOS Keychain (device-only, no iCloud)
- Clipboard auto-clear after 30 seconds
- Sign-out clears all local data

## Requirements

- macOS 26 or later
- A self-hosted Bitwarden or Vaultwarden server

## Getting Started for Development

```bash
git clone https://github.com/b0x42/macwarden.git
cd macwarden
open "Macwarden/Macwarden.xcodeproj"
```

Before building, set up your local signing config:

```bash
cp Macwarden/LocalConfig.xcconfig.template Macwarden/LocalConfig.xcconfig
```

Open `Macwarden/LocalConfig.xcconfig` and fill in your Apple Team ID (find it in Xcode → Settings → Accounts, or at developer.apple.com → Membership). A free Apple ID is sufficient for local development.

Then build and run with `⌘R`. No package managers or dependency installs needed.

### Debug Mode

Add `--debug-mode` to the Xcode scheme's Run → Arguments to enable verbose logging in the Data layer. Never enable in production — debug output includes cipher counts and HTTP response structure.

## Architecture

Clean Architecture with three layers and strict dependency direction:

```
App/              Entry point, DI container, root state machine
Domain/           Protocols, entities, use cases (zero dependencies)
Data/             Crypto, network, keychain, mappers, repository implementations
Presentation/     SwiftUI views and view models
```

- Swift 6 strict concurrency (`actor`, `@MainActor`, `nonisolated`)
- Zero third-party dependencies (except vendored [Argon2Swift](https://github.com/nicklama/Argon2Swift) for KDF)
- All encryption via CommonCrypto (FIPS 140-2) and CryptoKit

## Testing

`⌘U` in Xcode runs the full test suite:

- Unit tests for crypto, repositories, use cases, mappers, and UI components
- XCUITests for login, unlock, vault browsing, search, and keyboard navigation

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, code conventions, and how to submit changes.

## License

This project is not affiliated with Bitwarden, Inc.
