<!--
SYNC IMPACT REPORT
==================
Version change: 1.3.0 → 1.4.0
Modified principles:
  - VI: "Simplicity & YAGNI" → "Simplicity, YAGNI & Thin Layer"
    Added: thin integration layer mandate + tiered trusted-source reuse hierarchy
Added sections: N/A
Removed sections: N/A
Templates reviewed:
  - .specify/templates/plan-template.md        ✅ Updated (version ref + Principle III wording, prior session)
  - .specify/templates/spec-template.md        ✅ Compatible
  - .specify/templates/tasks-template.md       ✅ Compatible
Follow-up TODOs:
  - Register for a Bitwarden client identifier before connecting to live servers.
    See: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
  - Verify sdk-swift XCFramework contains a macOS slice (currently declares iOS only).
    File issue or fork if macOS slice is missing.
-->

# Bitwarden MacOS Constitution

## Core Principles

### I. Native-First Experience (NON-NEGOTIABLE)

Every UI surface MUST be built using Swift + SwiftUI targeting macOS natively.
No cross-platform frameworks (Electron, Flutter, Catalyst) are permitted.
The baseline UX target is 1Password-quality; features MUST aim to exceed it.

- Language: Swift (latest stable)
- UI Framework: SwiftUI
- Concurrency: Swift async/await + Structured Concurrency (no callback pyramids)
- Deployment target: current macOS major release and one prior (n-1)
- AppKit MAY be used only when SwiftUI has no equivalent API; usage MUST be documented
  and justified in the relevant plan's Complexity Tracking table

### II. Clean Architecture (NON-NEGOTIABLE)

The codebase MUST be organized into three strictly separated layers:

```
Presentation  →  Domain  →  Data
```

- **Domain layer**: Pure Swift. No UIKit/AppKit/SwiftUI imports. No network/storage
  imports. Contains entities, use cases, and repository protocols only.
- **Data layer**: Implements Domain protocols. Owns all Bitwarden API calls, Keychain
  access, CoreData/SQLite, and sync logic.
- **Presentation layer**: Owns ViewModels and SwiftUI Views. MUST NOT import Data
  layer directly; all data access flows through Domain use cases.
- Dependencies MUST only point inward (Presentation → Domain ← Data).
- Violations of layer boundaries are blocking PR rejections — no exceptions.

### III. Security-First / Zero-Trust (NON-NEGOTIABLE)

This is a credential vault. Security is not a feature — it is the foundation.

- Plaintext secrets (passwords, master key, session tokens) MUST NOT persist in memory
  beyond the minimum required lifetime; zero them on scope exit.
- All cryptographic operations and vault entity handling MUST use the official
  `BitwardenSdk` Swift package (https://github.com/bitwarden/sdk-swift) as the
  canonical implementation. Direct use of Apple CryptoKit for Bitwarden-protocol
  crypto is PROHIBITED — defer to the SDK.
- `BitwardenSdk` MUST be wrapped entirely within the Data layer. Domain and
  Presentation layers MUST NOT import `BitwardenSdk` directly; all SDK types
  are translated to internal Domain entities at the Data layer boundary.
- Custom Bitwarden crypto implementations are PROHIBITED. If the SDK does not
  cover a required operation, file an issue upstream before attempting a local
  implementation.
- All vault-touching code paths require a mandatory security review before merge.
- The app MUST support macOS App Sandbox and Hardened Runtime.
- Bitwarden API communication MUST use HTTPS/TLS only; certificate pinning SHOULD be
  evaluated per endpoint.
- Sensitive data shown in the UI MUST auto-clear after a configurable timeout.
- Clipboard writes containing secrets MUST auto-clear after ≤30 seconds (configurable).

### IV. Test-First / TDD (NON-NEGOTIABLE)

Red → Green → Refactor. No exceptions.

- Tests MUST be written and reviewed before implementation begins.
- Tests MUST fail before the implementation is written (Red phase verified).
- No PR may be merged if it introduces untested code paths in Domain or Data layers.
- Test pyramid:
  - **Unit tests**: All Domain use cases and Data layer transformations
  - **Integration tests**: Bitwarden API contracts, Keychain access, sync flows
  - **UI tests**: Critical user journeys (unlock, add entry, autofill)
- Test framework: XCTest (unit + integration), XCUITest (UI)
- Mocks are permitted in unit tests; integration tests MUST hit real or contract-
  verified stubs — never untested fakes for security-critical paths.

### V. Observability & Diagnosability

Silent failures are prohibited in vault and sync operations.

- Structured logging is REQUIRED for all vault, sync, auth, and crypto operations.
  Use `os.Logger` with subsystem = `com.bitwarden-macos` and appropriate categories.
- Log levels MUST be used correctly: `.debug` for trace, `.info` for normal flow,
  `.error` for recoverable faults, `.fault` for unrecoverable states.
- Secrets MUST NEVER appear in log output — scrub before logging.
- All async operations that can fail MUST surface errors to the Presentation layer
  via typed `Error` values; no swallowed `catch {}` blocks.

### VI. Simplicity, YAGNI & Thin Layer

Build what is needed now. Complexity must be earned, not anticipated. The client MUST
be a thin integration layer — delegate to existing trusted APIs and libraries wherever
available.

- No premature abstractions: three similar call sites are acceptable before extracting
  a shared helper.
- No feature flags, backwards-compat shims, or dead code paths — delete unused code.
- Every non-obvious architectural decision MUST be documented in the relevant plan's
  Complexity Tracking table with a justification and rejected simpler alternative.
- Over-engineering is a defect, treated the same as a functional bug.
- **Reuse over rebuild**: Custom implementations are only permitted when no suitable
  trusted library exists. Trusted sources, in order of preference:
  1. Apple first-party frameworks (SwiftUI, Foundation, CryptoKit, AuthenticationServices…)
  2. Bitwarden official SDK (`BitwardenSdk` / sdk-swift)
  3. Well-maintained, open-source Swift community packages (actively maintained,
     significant adopter base, auditable source)
  When a custom implementation is unavoidable, justify it in the Complexity Tracking
  table and file an upstream issue where applicable.

## Security Requirements

Mandatory security constraints binding all contributors:

- **Keychain only**: Master key, session tokens, and derived secrets MUST be stored
  exclusively in the macOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **No iCloud sync of secrets**: Keychain items holding vault secrets MUST NOT use
  `kSecAttrSynchronizable = true`.
- **Autofill extension**: If implemented, MUST operate in a separate process with
  minimum entitlements; MUST NOT retain secrets beyond the autofill request lifecycle.
- **Dependency vetting**: All third-party Swift packages MUST be reviewed for supply-
  chain risk before inclusion. Prefer Apple-first APIs; minimize external dependencies.
  When Apple provides no equivalent, use a trusted library (Bitwarden SDK or a
  well-maintained Swift community package) rather than building a custom implementation.
- **App Transport Security**: ATS MUST remain enabled. No `NSAllowsArbitraryLoads`.
- **Memory hardening**: Use `SecureBytes` or equivalent zeroing wrappers for all
  in-memory secret buffers.

### Bitwarden Normative Standards

This project treats the official Bitwarden client security requirements as a normative
external standard. All requirements below are binding in addition to the principles above.

Reference: https://contributing.bitwarden.com/architecture/security/requirements/

- **Vault data at rest**: Vault data MUST be encrypted on disk. Encryption keys MUST NOT
  be stored such that vault data can be decrypted without additional information provided
  by the user (no key escrow, no ambient-authority decryption).
- **Vault data in use**: Decryption during the unlock session is permitted, but the
  quantity of unencrypted data in memory MUST be minimized and removed when no longer
  needed.
- **Vault data in transit**: Trusted channels are REQUIRED whenever data crosses process
  or device boundaries where eavesdropping risk exists.
- **UserKey**: MUST provide 256-bit security strength. MUST NOT be exported.
  MAY remain unprotected in memory during active use only.
- **Authentication tokens**: MUST be protected at rest when secure storage mechanisms
  exist (macOS Keychain satisfies this). Transit protection is mandatory.
- **Export consent**: User consent is mandatory before any vault export operation.

### Bitwarden API Integration Requirements

Before connecting to live Bitwarden servers, this client MUST be registered:

- **Client identifier**: Contact Bitwarden Customer Success via support ticket to obtain
  a registered client identifier and device type enum value.
  See: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
- **Required headers**: All API requests MUST include the minimum required headers as
  specified by Bitwarden. Missing headers → `400 Bad Request`; invalid values → `403 Forbidden`.
- **Client version string**: MUST accurately reflect the Bitwarden server release the
  client has been certified/tested against.
- **TODO**: Register client identifier before first production API connection.

## External Dependencies

### Bitwarden iOS App (Reference Implementation)

- **Repository**: https://github.com/bitwarden/ios
- **Purpose**: Official Bitwarden Swift/SwiftUI client for iOS — the closest production
  reference available for architecture, `sdk-swift` integration patterns, API usage,
  and XCTest/XCUITest setup.
- **How to use**: Study only — do not copy code verbatim. Use as a reference for:
  - How `BitwardenSdk` modules are integrated in a real Swift project
  - Bitwarden API request/response patterns in Swift
  - Clean Architecture layer separation in an Apple-platform Bitwarden client
  - Test structure and coverage patterns
- **Note**: iOS-specific UI and lifecycle code does not apply directly; adapt patterns
  to macOS/SwiftUI conventions.

### BitwardenSdk (Canonical — REQUIRED)

- **Repository**: https://github.com/bitwarden/sdk-swift
- **Purpose**: Official Bitwarden Rust core SDK wrapped as a Swift Package via UniFFI FFI.
  Provides all Bitwarden-protocol crypto, vault entity models, password/passphrase
  generation, FIDO2/WebAuthn, Send, and export functionality.
- **Modules in use**:
  - `BitwardenCore` — auth flows, client settings, key initialization
  - `BitwardenCrypto` — KDF (PBKDF2/Argon2), RSA, hash operations
  - `BitwardenVault` — cipher/vault entity models
  - `BitwardenGenerators` — password and passphrase generation
  - `BitwardenFido` — FIDO2/WebAuthn credential operations
  - `BitwardenSend` — Bitwarden Send feature
  - `BitwardenExporters` — vault export formats
- **Architecture rule**: Consumed exclusively in the Data layer. MUST be wrapped behind
  internal Domain protocols; never leaks into Domain or Presentation.
- **Known risk**: `Package.swift` declares iOS-only platform (`.iOS(.v13)`).
  TODO: Verify the XCFramework contains a macOS slice before integration;
  open upstream issue or fork if absent.
- **Supply-chain note**: Distributed as a binary XCFramework from Azure blob storage.
  Pin the checksum in `Package.swift` and review on every SDK version bump.

## Development Workflow

Standards governing how features are built and shipped:

- **Spec before code**: Every non-trivial feature MUST have a spec (`spec.md`) and
  implementation plan (`plan.md`) reviewed before implementation begins.
- **Branch per feature**: Work on named feature branches; never commit directly to
  `main`. Branch naming: `###-short-description` (e.g., `001-vault-unlock`).
- **PR requirements**: All PRs MUST pass CI (build + tests), include a Constitution
  Check verification, and receive at least one review before merge.
- **Commit discipline**: Commits MUST be atomic and descriptive. One logical change
  per commit. Use conventional commit format: `type(scope): description`.
- **No WIP merges**: Incomplete features MUST use feature flags or remain on branch
  until the full user story is independently testable and passing.
- **Changelog**: Every merged PR that changes user-visible behavior MUST include a
  changelog entry.

## Governance

- This Constitution supersedes all other development practices, guidelines, and
  conventions. In any conflict, the Constitution wins.
- **Amendment procedure**:
  1. Open a proposal issue describing the change and motivation.
  2. Discuss and reach consensus (or majority decision for solo projects: author
     documents the rationale).
  3. Update this file, increment the version per semantic versioning rules, and
     update `Last Amended` date.
  4. Propagate changes to all dependent templates (see Sync Impact Report header).
- **Versioning policy**:
  - MAJOR: Backward-incompatible removal or redefinition of a principle.
  - MINOR: New principle or section added, or materially expanded guidance.
  - PATCH: Clarifications, wording fixes, non-semantic refinements.
- **Compliance review**: Every PR review MUST include a Constitution Check — confirm
  the changes do not violate any principle. Violations are blocking.
- **Runtime guidance**: Use CLAUDE.md (agent-context file) for session-level
  development guidance; the Constitution governs long-term architectural rules.

**Version**: 1.4.0 | **Ratified**: 2026-03-12 | **Last Amended**: 2026-03-13
