# Development Guide

## Prerequisites

- **Xcode 26** (beta or release) — the project requires the macOS 26 SDK
- **macOS 26** or later on the development machine
- An Apple ID (free) for local builds; a paid Apple Developer account for release signing

No package managers required. Dependencies are vendored under `LocalPackages/`.

## Cloning and Setup

```bash
git clone https://github.com/b0x42/prizm.git
cd prizm
```

### LocalConfig.xcconfig (required before building)

The project requires a per-developer signing config file that is not committed to the repository:

```bash
cp Prizm/LocalConfig.xcconfig.template Prizm/LocalConfig.xcconfig
```

Open `Prizm/LocalConfig.xcconfig` and fill in `DEVELOPMENT_TEAM`:

```
DEVELOPMENT_TEAM = AB12CD34EF
```

**Where to find your Team ID:**

- Xcode → Settings → Accounts → select your Apple ID → the Team ID is in parentheses
- Or: [developer.apple.com](https://developer.apple.com) → Account → Membership → Team ID

A free Apple ID ("Personal Team") works for local builds. You do not need a paid account to run the app on your own Mac.

> **The build will fail without this file.** `LocalConfig.xcconfig` is git-ignored so your Team ID never appears in the repository.

## Building

Open the project in Xcode:

```bash
open "Prizm/Prizm.xcodeproj"
```

Then press `⌘R` to build and run. No additional steps needed.

Or build from the command line:

```bash
xcodebuild -project "Prizm/Prizm.xcodeproj" \
           -scheme "Prizm" \
           -configuration Debug \
           build
```

## Running Tests

Press `⌘U` in Xcode, or from the command line:

```bash
xcodebuild test \
  -project "Prizm/Prizm.xcodeproj" \
  -scheme "Prizm" \
  -destination "platform=macOS"
```

All tests must pass before merging to `main`. The CI workflow enforces this on every push and pull request.

## Architecture

Three-layer Clean Architecture with strict dependency direction:

```
App/              @main entry point, DI container, root state machine
Domain/           Protocols, entities, use cases — import Foundation only
Data/             Crypto, network, keychain, mappers, repository implementations
Presentation/     SwiftUI views and view models — import SwiftUI only
```

**Rules:**
- `Domain` has zero dependencies on `Data` or `Presentation`
- `Presentation` never imports `Data`, `CommonCrypto`, `CryptoKit`, or `Argon2Swift`
- `Data` is the only layer that imports crypto frameworks
- All cross-layer communication happens through protocols defined in `Domain`

See `CONSTITUTION.md` for the full set of non-negotiable architectural constraints.

## openspec Workflow

Feature changes are tracked in `openspec/changes/<name>/`. Each change has three artifacts:

- `proposal.md` — what and why
- `design.md` — how (data model, API surface, decision log)
- `tasks.md` — numbered implementation steps

Changes are implemented task-by-task (TDD: write failing test → implement → refactor) and archived to `openspec/changes/archive/` when complete.

To explore or propose a change, use the `/opsx:` skills in Claude Code.

## Contributing

1. Open an issue describing what you want to build or fix
2. For non-trivial changes, create an openspec change with proposal and design before writing code
3. Implement with TDD — failing test first, then implementation
4. All tests must pass; no regressions
5. All icon-only buttons must have an `accessibilityLabel`; see `ACCESSIBILITY.md` for conformance details
6. Open a pull request with a clear description

## GitHub Secrets (Release Signing)

The release workflow (`.github/workflows/release.yml`) requires the following secrets configured in GitHub Settings → Secrets and variables → Actions:

| Secret | Description | How to obtain |
|---|---|---|
| `CERT_P12` | Developer ID Application certificate, base64-encoded `.p12` file | Xcode → Settings → Accounts → Manage Certificates → export Developer ID Application cert |
| `CERT_PASSWORD` | Password used when exporting the `.p12` | Set during export |
| `NOTARYTOOL_KEY` | App Store Connect API key (`.p8` file), base64-encoded | [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Integrations → App Store Connect API → generate key with Developer role |
| `NOTARYTOOL_KEY_ID` | App Store Connect API key ID (10-character string) | Shown next to the key in App Store Connect |
| `NOTARYTOOL_ISSUER_ID` | App Store Connect Issuer ID (UUID) | Shown at the top of the API Keys page in App Store Connect |
| `TEAM_ID` | Your 10-character Apple Developer Team ID | developer.apple.com → Account → Membership |

Base64-encode a file for use as a secret:

```bash
base64 -i YourCert.p12 | pbcopy   # copies to clipboard
```

Without these secrets, the signing and notarization steps will fail. For local development, you only need `LocalConfig.xcconfig` — no secrets required.
