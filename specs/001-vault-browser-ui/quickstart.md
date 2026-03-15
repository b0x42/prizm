# Quickstart: 001-vault-browser-ui

## Prerequisites

- macOS 14 (Sonoma) or macOS 13 (Ventura)
- Xcode 16+ (latest stable)
- Swift 5.10+
- A self-hosted Bitwarden or Vaultwarden account

## Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/b0x42/bitwarden-macos.git
   cd bitwarden-macos
   git checkout 001-vault-browser-ui
   ```

2. **Open the Xcode project**
   ```bash
   open "Bitwarden MacOS/Bitwarden MacOS.xcodeproj"
   ```
   `Argon2Swift` is vendored locally at `LocalPackages/Argon2Swift/` and referenced as an
   `XCLocalSwiftPackageReference` — no internet access or package resolution needed.
   No SDK XCFramework is needed — crypto is implemented natively via CommonCrypto + CryptoKit.

3. **Verify the build compiles**
   ```bash
   xcodebuild -project "Bitwarden MacOS/Bitwarden MacOS.xcodeproj" \
     -scheme "Bitwarden MacOS" -configuration Debug build
   ```
   Expected: `BUILD SUCCEEDED`.

4. **Client identifier** (self-hosted only — no registration needed)
   - v1 targets self-hosted Bitwarden and Vaultwarden only. Self-hosted servers do not
     enforce a client whitelist.
   - Set `Config.clientName = "desktop"` and `Config.deviceType = 7` in
     `Bitwarden_MacOS/App/Config.swift` — these are accepted by all self-hosted instances.
   - Note: `Config.swift` holds only the static client identifier and device type. The
     **server URL** is entered by the user at login time and persisted in the Keychain
     per-user (`bw.macos:{userId}:serverEnvironment`) — it is not in `Config.swift`.
   - Registration with Bitwarden Customer Success is required only when cloud (US/EU)
     support is added in a future version.

## Build & Run

```bash
# From Xcode: ⌘R
# Or from command line:
xcodebuild -project "Bitwarden MacOS/Bitwarden MacOS.xcodeproj" \
           -scheme "Bitwarden MacOS" \
           -configuration Debug \
           build
```

## Run Tests

```bash
xcodebuild test \
  -project "Bitwarden MacOS/Bitwarden MacOS.xcodeproj" \
  -scheme "Bitwarden MacOS" \
  -destination "platform=macOS"
```

Or in Xcode: **⌘U**

## Project Structure

```
Bitwarden_MacOS/
├── Bitwarden_MacOS.xcodeproj/
└── Bitwarden_MacOS/
    ├── App/
    │   ├── BitwardenMacOSApp.swift     # @main entry point
    │   ├── AppContainer.swift          # Dependency injection (manual)
    │   └── Config.swift                # Client identifier, device type, app version
    │
    ├── Domain/
    │   ├── Entities/                   # VaultItem, Account, ServerEnvironment, etc.
    │   ├── UseCases/                   # LoginUseCase, UnlockUseCase, SyncUseCase, etc.
    │   └── Repositories/              # AuthRepository, VaultRepository, SyncRepository (protocols)
    │
    ├── Data/
    │   ├── Crypto/                     # BitwardenCryptoService protocol + impl, EncString, CryptoKeys
    │   ├── Network/                    # BitwardenAPIClient (URLSession), Models/, FaviconLoader
    │   ├── Keychain/                   # KeychainService
    │   ├── Repositories/              # AuthRepositoryImpl, VaultRepositoryImpl, SyncRepositoryImpl
    │   └── Mappers/                    # RawCipher → Domain VaultItem
    │
    ├── Presentation/
    │   ├── Auth/
    │   │   ├── LoginView.swift
    │   │   ├── LoginViewModel.swift
    │   │   ├── UnlockView.swift
    │   │   ├── UnlockViewModel.swift
    │   │   ├── SyncProgressView.swift
    │   │   └── ServerSelectionView.swift
    │   ├── Vault/
    │   │   ├── VaultBrowserView.swift         # NavigationSplitView root
    │   │   ├── VaultBrowserViewModel.swift
    │   │   ├── Sidebar/
    │   │   │   └── SidebarView.swift
    │   │   ├── ItemList/
    │   │   │   ├── ItemListView.swift
    │   │   │   └── ItemRowView.swift
    │   │   └── Detail/
    │   │       ├── ItemDetailView.swift
    │   │       ├── LoginDetailView.swift
    │   │       ├── CardDetailView.swift
    │   │       ├── IdentityDetailView.swift
    │   │       ├── SecureNoteDetailView.swift
    │   │       └── SSHKeyDetailView.swift
    │   └── Components/
    │       ├── FieldRowView.swift             # hover-reveal row
    │       ├── MaskedFieldView.swift          # fixed-length masking
    │       └── FaviconView.swift              # favicon + fallback icon
    │
    └── Tests/
        ├── DomainTests/
        │   ├── UseCases/
        │   └── Entities/
        ├── DataTests/
        │   ├── Crypto/
        │   ├── Repositories/
        │   ├── Mappers/
        │   └── Network/
        ├── PresentationTests/
        │   └── Components/
        └── UITests/

```

## Architecture Rules (enforced at PR review)

1. **Domain layer**: `import Foundation` only. No crypto, no SwiftUI, no AppKit.
2. **Data layer**: Only place that imports CommonCrypto, CryptoKit, Security, or Argon2Swift.
   All crypto behind `BitwardenCryptoService` protocol. RawCipher types translated to
   Domain entities at the boundary via `CipherMapper`.
3. **Presentation layer**: Only place that imports `SwiftUI`. Uses Domain use cases; never
   imports Data layer or crypto modules directly.
4. **TDD**: Write the test first. Commit the failing test before writing the implementation.

## Key Development Flows

### Adding a new detail field

1. Add field to the Domain entity in `Domain/Entities/`.
2. Update `CipherMapper` in `Data/Mappers/`.
3. Update the detail SwiftUI view in `Presentation/Vault/Detail/`.
4. Write a unit test for the mapper. Write a UI snapshot/test for the detail view.

### Adding a new sidebar category

1. Add a case to `SidebarSelection` in `Domain/Entities/SidebarSelection.swift`.
2. Update `VaultRepository.items(for:)` filter logic.
3. Update `SidebarView` rendering.
4. Update `VaultRepository.itemCounts()`.
