<!--
SYNC IMPACT REPORT
==================
Version change: 1.3.0 → 1.4.0
Bump type: MINOR — §III materially revised (native crypto replaces sdk-swift mandate);
           §VII added (Radical Transparency, new principle).
Modified principles:
  - §III Security-First / Zero-Trust: removed sdk-swift mandate (sdk-internal inaccessible,
    sdk-swift iOS-only); replaced with native Apple framework crypto wrapped behind a
    BitwardenCryptoService protocol. Direct CryptoKit prohibition replaced with
    "no hand-rolled algorithms" rule.
  - External Dependencies: BitwardenSdk section updated from REQUIRED to ARCHIVED status;
    Argon2Swift added as the only approved external crypto dependency.
Added sections:
  - §VII Radical Transparency (new principle)
Removed sections: N/A
Templates requiring updates:
  - specs/001-vault-browser-ui/plan.md        ✅ updated (§III constitution check)
  - specs/001-vault-browser-ui/research.md    ✅ updated (OI-001 closed, native crypto)
  - specs/001-vault-browser-ui/data-model.md  ✅ updated (crypto flow)
  - specs/001-vault-browser-ui/tasks.md       ✅ updated (Phase 1 + Phase 3)
  - CLAUDE.md                                 ⚠ pending — §III reference needs update
Follow-up TODOs:
  - Update CLAUDE.md §III reference to reflect native crypto approach.
  - Register for a Bitwarden client identifier before connecting to live servers.
    See: https://contributing.bitwarden.com/architecture/adr/integration-identifiers/
-->

# Bitwarden macOS Constitution

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
  access, CoreData/SQLite, sync logic, and all cryptographic operations.
- **Presentation layer**: Owns ViewModels and SwiftUI Views. MUST NOT import Data
  layer directly; all data access flows through Domain use cases.
- Dependencies MUST only point inward (Presentation → Domain ← Data).
- Violations of layer boundaries are blocking PR rejections — no exceptions.

### III. Security-First / Zero-Trust (NON-NEGOTIABLE)

This is a credential vault. Security is not a feature — it is the foundation.

- Plaintext secrets (passwords, master key, session tokens) MUST NOT persist in memory
  beyond the minimum required lifetime; zero them on scope exit.
- All cryptographic operations MUST use vetted, well-understood implementations:
  - **Preferred**: Apple system frameworks — CommonCrypto, CryptoKit, Security.framework.
    These are audited, maintained, and hardware-accelerated on Apple silicon.
  - **Permitted exception**: `Argon2Swift` (thin Swift wrapper around the reference
    C implementation) for Argon2id KDF, which is not provided by Apple frameworks.
  - **All other third-party crypto libraries are PROHIBITED** without a formal
    constitution amendment documenting the rationale and supply-chain review.
- Hand-rolled implementations of cryptographic algorithms (AES, HMAC, KDF, RSA) are
  PROHIBITED regardless of the source. Always use a vetted library.
- All crypto operations MUST be wrapped entirely within the Data layer behind a
  `BitwardenCryptoService` protocol. Domain and Presentation layers MUST NOT import
  crypto modules directly; all types are translated to Domain entities at the boundary.
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
- Crypto implementations MUST include known-answer tests (KATs) against published
  test vectors from the relevant standard (NIST, RFC, Bitwarden Security Whitepaper).
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

### VI. Simplicity & YAGNI

Build what is needed now. Complexity must be earned, not anticipated.

- No premature abstractions: three similar call sites are acceptable before extracting
  a shared helper.
- No feature flags, backwards-compat shims, or dead code paths — delete unused code.
- Every non-obvious architectural decision MUST be documented in the relevant plan's
  Complexity Tracking table with a justification and rejected simpler alternative.
- Over-engineering is a defect, treated the same as a functional bug.

### VII. Radical Transparency (NON-NEGOTIABLE)

This project is a password manager. Users must be able to verify that it is safe.
Every security-critical implementation decision MUST be documented for public auditability.

- Crypto code MUST include inline comments explaining:
  - **What** each step does (e.g. "derive 64-byte stretched key via HKDF-SHA256")
  - **Why** it exists (e.g. "MAC verified before decrypt to prevent padding oracle attacks")
  - **Which standard** it implements, cited by name and section
    (e.g. "Bitwarden Security Whitepaper §4.1", "RFC 5869 §2", "NIST SP 800-132")
- Non-obvious algorithm choices (key stretching rationale, HKDF label values,
  MAC-then-verify ordering, EncString type selection) MUST have a comment explaining
  the security property they provide.
- Each Data layer file touching cryptography MUST open with a doc comment block
  summarising its purpose, the standards it follows, and any known limitations.
- A `SECURITY.md` at the repo root MUST document in plain language:
  - What data is encrypted and with what algorithm
  - Where keys are stored and under what conditions they are accessible
  - What threat model the app defends against
  - What the app explicitly does NOT protect against
- The goal: any developer — or technically literate user — MUST be able to read the
  source and independently verify that the implementation is correct and safe.
  **No black boxes. No "trust us".**

---

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
- **App Transport Security**: ATS MUST remain enabled. No `NSAllowsArbitraryLoads`.
- **Memory hardening**: Use zeroing wrappers for all in-memory secret buffers;
  secrets MUST NOT be stored in Swift `String` longer than necessary.

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

---

## External Dependencies

### Argon2Swift (Approved — Narrow Scope)

- **Repository**: https://github.com/tmthecoder/Argon2Swift
- **Purpose**: Argon2id KDF support. Bitwarden made Argon2id the default KDF for new
  accounts in 2023. Most new accounts require it; PBKDF2-only support would block a
  large portion of users.
- **Why not Apple frameworks**: Argon2id is not available in CommonCrypto or CryptoKit.
  This is the only approved exception to the Apple-frameworks-first rule for crypto.
- **Implementation**: Thin Swift wrapper around the reference C implementation of Argon2
  (same code used in the official Argon2 reference library). No custom algorithm.
- **Scope**: Used exclusively in `BitwardenCryptoServiceImpl` for KDF only.
  MUST NOT be used for any purpose other than Argon2id key derivation.
- **Supply-chain note**: Pin the exact version and review on every bump.

### Bitwarden iOS App (Reference — Study Only)

- **Repository**: https://github.com/bitwarden/ios
- **Purpose**: Official Bitwarden Swift/SwiftUI client for iOS — the closest production
  reference available for architecture, API usage, and XCTest/XCUITest setup.
- **How to use**: Study only — do not copy code verbatim. Use as a reference for:
  - Bitwarden API request/response patterns in Swift
  - Clean Architecture layer separation in an Apple-platform Bitwarden client
  - Test structure and coverage patterns
- **Note**: iOS-specific UI and lifecycle code does not apply directly; adapt patterns
  to macOS/SwiftUI conventions.

### BitwardenSdk / sdk-swift (ARCHIVED — Not Used)

- **Repository**: https://github.com/bitwarden/sdk-swift
- **Status**: Evaluated and rejected for v1. `sdk-swift` distributes an iOS-only
  XCFramework (`ios-arm64`, `ios-arm64_x86_64-simulator`); no macOS slice exists in
  any release. `sdk-internal` (which contains the UniFFI Swift bindings and macOS
  build scripts) is a private Bitwarden repository and is not accessible.
- **Revisit**: If Bitwarden officially packages a macOS slice of `BitwardenFFI.xcframework`
  in a future release, migrating to `sdk-swift` SHOULD be evaluated. The
  `BitwardenCryptoService` protocol boundary makes this swap straightforward.

---

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

---

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
- **Runtime guidance**: Use `CLAUDE.md` (agent-context file) for session-level
  development guidance; the Constitution governs long-term architectural rules.

---

**Version**: 1.4.0 | **Ratified**: 2026-03-12 | **Last Amended**: 2026-03-15
