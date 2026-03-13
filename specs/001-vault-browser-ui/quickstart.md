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
   open Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj
   ```
   (The project will resolve the `BitwardenSdk` Swift package automatically on first open.)

3. **Verify BitwardenSdk macOS support**
   ```bash
   # After SPM resolves packages, find the XCFramework:
   find ~/Library/Developer/Xcode/DerivedData -name "BitwardenSdk.xcframework" 2>/dev/null | head -1
   # Then check for macOS slice:
   lipo -info <path>/BitwardenSdk.xcframework/macos-arm64_x86_64/BitwardenSdk.framework/BitwardenSdk
   ```
   Expected output should include `arm64` and `x86_64` for macOS.
   If this step fails, see `research.md` Open Items §1 before proceeding.

4. **Client identifier** (self-hosted: no registration needed)
   - v1 targets self-hosted Bitwarden and Vaultwarden only. Self-hosted servers do not
     enforce a client whitelist.
   - Set `Config.clientName = "desktop"` and `Config.deviceType = 7` in
     `Sources/App/Config.swift` — these are accepted by all self-hosted instances.
   - Note: `Config.swift` holds only the static client identifier and device type. The
     **server URL** is entered by the user at login time and persisted in the Keychain
     per-user (`bw.macos:{userId}:serverEnvironment`) — it is not in `Config.swift`.
   - Registration with Bitwarden Customer Success is required only when cloud (US/EU)
     support is added in a future version.

## Build & Run

```bash
# From Xcode: ⌘R
# Or from command line:
xcodebuild -project Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj \
           -scheme "Bitwarden MacOS" \
           -configuration Debug \
           build
```

## Run Tests

```bash
xcodebuild test \
  -project Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj \
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
    │   ├── SDK/                        # BitwardenSdkClientService (wraps SDK Client)
    │   ├── Network/                    # BitwardenNetworkClient (URLSession-based)
    │   ├── Keychain/                   # KeychainService
    │   ├── Repositories/              # AuthRepositoryImpl, VaultRepositoryImpl, SyncRepositoryImpl
    │   └── Mappers/                    # SDK type → Domain entity mappers
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
        │   ├── Repositories/
        │   ├── Mappers/
        │   └── Network/
        └── UITests/

```

## Architecture Rules (enforced at PR review)

1. **Domain layer**: No `import BitwardenSdk`. No `import SwiftUI`. Pure Swift.
2. **Data layer**: Only place that imports `BitwardenSdk`. All SDK types translated at the
   Data/Domain boundary via mappers.
3. **Presentation layer**: Only place that imports `SwiftUI`. Uses Domain use cases; never
   imports Data layer directly.
4. **TDD**: Write the test first. Commit the failing test before writing the implementation.

## Key Development Flows

### Adding a new detail field

1. Add field to the Domain entity in `Domain/Entities/`.
2. Update the SDK mapper in `Data/Mappers/`.
3. Update the detail SwiftUI view in `Presentation/Vault/Detail/`.
4. Write a unit test for the mapper. Write a UI snapshot/test for the detail view.

### Adding a new sidebar category

1. Add a case to `SidebarSelection` in `Domain/Entities/SidebarSelection.swift`.
2. Update `VaultRepository.items(for:)` filter logic.
3. Update `SidebarView` rendering.
4. Update `VaultRepository.itemCounts()`.
