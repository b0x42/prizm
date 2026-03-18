# Contributing

Thanks for your interest in contributing to Bitwarden for macOS! This document covers how to get started, the project conventions, and how to submit changes.

## About the Author

Hi, I'm Benjamin ([@b0x42](https://github.com/b0x42)). I build tools that scratch my own itch — from self-hosted infrastructure and home automation to hardware projects and native apps:

- [**pi-weather-ink**](https://github.com/b0x42/pi-weather-ink) — Raspberry Pi weather station with Waveshare e-Paper displays (Python)
- [**E-Paper-Emulator**](https://github.com/b0x42/E-Paper-Emulator) — Drop-in Waveshare e-Paper emulator for desktop development (Python)
- [**dns-racing**](https://github.com/b0x42/dns-racing) — Compare your local DNS server latency against public resolvers (Node.js)
- [**db-meetingstation-public**](https://github.com/b0x42/db-meetingstation-public) — Shortest-path station finder for Deutsche Bahn (Java)
- [**bitwarden-macos**](https://github.com/b0x42/bitwarden-macos) — Native read-only Bitwarden/Vaultwarden client for macOS (Swift)

## Getting Started

### Prerequisites

- macOS 13+ (Ventura or later)
- Xcode 15+
- A self-hosted Bitwarden or Vaultwarden server for testing

### Setup

```bash
git clone https://github.com/b0x42/bitwarden-macos.git
cd bitwarden-macos
open "Bitwarden MacOS/Bitwarden MacOS.xcodeproj"
```

No package managers or dependency installs needed — the only external dependency (Argon2Swift) is vendored.

### Running Tests

In Xcode: `⌘U` to run all unit tests, or use the Test navigator to run individual suites.

## Architecture

The project follows Clean Architecture with three layers:

```
Domain/          Protocols, entities, use cases (no dependencies)
  ├── Entities/
  ├── Repositories/
  └── UseCases/

Data/            Implementations (crypto, network, keychain, mappers)
  ├── Crypto/
  ├── Network/
  ├── Keychain/
  ├── Mappers/
  ├── Repositories/
  └── UseCases/

Presentation/    SwiftUI views and view models
  ├── Login/
  ├── Unlock/
  ├── Vault/
  ├── Sync/
  └── Components/

App/             Entry point, DI container, root state machine
```

## Code Conventions

### Swift Style

- Swift 6 strict concurrency — use `actor`, `@MainActor`, and `nonisolated` correctly
- Protocols in Domain, implementations in Data
- `@MainActor` on all view models and UI-facing classes
- `nonisolated` on value types that cross actor boundaries
- Prefer `let` over `var`; prefer value types over reference types

### Naming

- Types: `PascalCase`
- Properties/functions: `camelCase`
- Protocols: noun or adjective (e.g. `AuthRepository`, `BitwardenCryptoService`)
- Implementations: protocol name + `Impl` suffix (e.g. `AuthRepositoryImpl`)

### Security

- Never log key material, tokens, or passwords
- Use `privacy: .private` for PII in `os.log` calls
- Debug logging is gated behind `DebugConfig.isEnabled` (opt-in via `--debug-mode`)
- Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

## How to Contribute

### Reporting Issues

Open an issue with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- macOS version and Xcode version

### Submitting Changes

1. Fork the repo and create a branch from `main`
2. Make your changes following the conventions above
3. Run the test suite (`⌘U`) and make sure everything passes
4. Open a pull request against `main`

Keep PRs focused — one feature or fix per PR.

### What's Welcome

- Bug fixes
- New cipher type support
- Accessibility improvements
- Performance improvements
- Documentation

### What's Out of Scope (for now)

- Write/edit operations (this is a read-only client)
- Organisation vault support
- Browser extension or iOS port

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
