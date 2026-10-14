# Implementation Plan: TOTP Verification Codes

**Branch**: `001-totp-verification-codes` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-totp-verification-codes/spec.md`

## Summary

Show the current TOTP code for Login items, in the detail pane and in a new "Verification Codes" sidebar list. Codes are derived on demand from the seed already held in the decrypted vault, using RFC 6238 over HMAC from the Data-layer crypto service. Nothing new is stored. A single tracker refreshes codes once per second only while a code view is on screen, the app is not hidden or minimized, and the vault is unlocked. "Copy Code" (⌃⌘C) is changed to copy the generated code, and the raw-seed copy is removed.

Approach (see [research.md](research.md)):

- **Domain** (Foundation only): seed parsing (plain base32 and `otpauth://totp`), the code value type, and a `GenerateTOTPCodeUseCase` protocol.
- **Data**: one new stateless HMAC operation on `PrizmCryptoService` (CryptoKit), and the use case implementation that combines the parsed seed with it.
- **Presentation**: a `.verificationCodes` sidebar selection, a list view, a detail-pane card, and a shared tracker view model.

## Technical Context

**Language/Version**: Swift 6.2 (Swift 6 language mode)

**Primary Dependencies**: SwiftUI, CryptoKit (HMAC-SHA1/256/512). No new packages.

**Storage**: None. Codes are never stored. Seeds are read from the existing in-memory decrypted vault.

**Testing**: XCTest (unit: parser, use case with RFC 6238 vectors, tracker view model, repository index; integration: lock behavior). XCUITest for the sidebar-to-copy journey.

**Target Platform**: macOS 26+ (App Sandbox + Hardened Runtime unchanged)

**Project Type**: macOS desktop app

**Performance Goals**: New code visible within 1 s of the period ending (SC-004). Sidebar to copied code under 10 s (SC-002). One refresh pass for 100 seeds takes well under 50 ms on the main-actor budget [assumption, to be measured in tasks].

**Constraints**: No hand-rolled HMAC. Crypto only in the Data layer behind `PrizmCryptoService`. No logging of seeds or codes. No refresh while locked, hidden/minimized, or off-screen. Merely losing focus does not hide codes. Design tokens only, no raw font or spacing literals.

**Scale/Scope**: Tens to low hundreds of items with seeds. One new sidebar entry, one list view, one detail card, one menu command changed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design (below).*

| Principle | Status | Notes |
|---|---|---|
| I. Native-First | Pass | SwiftUI only. No AppKit needed. |
| II. Clean Architecture | Pass | Domain stays `import Foundation`. HMAC lives in Data. Presentation reaches code generation only through a Domain use case. |
| III. Security-First | Pass with a requested exception | Vetted CryptoKit HMAC behind `PrizmCryptoService`. Seeds never logged or stored. Clipboard clears in 30 s. Codes are removed on lock. **Exception**: TOTP codes are always visible, like other TOTP apps, and are exempt from the "sensitive data shown in the UI MUST auto-clear after a configurable timeout" rule. The Constitution wins in a conflict, so the exception is made by a narrow amendment (task in tasks.md). See Complexity Tracking. |
| IV. TDD | Pass | RFC 6238 Appendix B and RFC 4226 Appendix D known-answer tests written first. |
| V. Observability | Pass | Failures surface as typed errors. Logging via `os.Logger` with no secret content. |
| VI. Simplicity | Pass | One tracker reused by both views. No caching of parsed seeds. No new settings. |
| VII. Radical Transparency | Pass | Inline comments cite RFC 6238 §4, RFC 4226 §5.3, and the SHA-1 rationale. `SECURITY.md` gets a TOTP section. |
| VIII. Accessibility | Pass | Labels, `.isHeader`, non-color expiry cue, no per-tick announcements. `ACCESSIBILITY.md` updated. |

**Gate result**: pass, conditional on amending §III with the TOTP exception (Constitution Governance: amendment procedure, MINOR bump). The exception is justified below and needs a security review at PR time (Constitution: all vault-touching code).

**Post-design re-check**: unchanged. The design adds no new dependency, no new storage, and no layer violation.

## Project Structure

### Documentation (this feature)

```text
specs/001-totp-verification-codes/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── domain-protocols.md
│   └── ui-contract.md
└── tasks.md             # Phase 2 output (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
Prizm/
├── Domain/
│   ├── Entities/
│   │   ├── SidebarSelection.swift        # + .verificationCodes case, equality, hash, name
│   │   └── TOTPCode.swift                # NEW: code value, grouping, time remaining
│   ├── Utilities/
│   │   └── TOTPSeedParser.swift          # NEW: base32 + otpauth parsing (Foundation only)
│   └── UseCases/
│       └── GenerateTOTPCodeUseCase.swift # NEW: protocol + TOTPError
├── Data/
│   ├── Crypto/
│   │   └── PrizmCryptoService.swift      # + hmac(algorithm:key:message:)
│   ├── Repositories/
│   │   └── VaultRepositoryImpl.swift     # + .verificationCodes index and count
│   └── UseCases/
│       └── GenerateTOTPCodeUseCaseImpl.swift  # NEW
├── Presentation/
│   ├── Vault/
│   │   ├── VerificationCodes/
│   │   │   ├── TOTPCodesViewModel.swift       # NEW: shared once-per-second tracker
│   │   │   ├── VerificationCodesListView.swift # NEW: list pane
│   │   │   └── TOTPCodeRowView.swift          # NEW: row + countdown indicator
│   │   ├── Detail/LoginDetailView.swift       # + "Verification Code" card
│   │   ├── Sidebar/SidebarView.swift          # + sidebar row
│   │   └── VaultBrowserView.swift             # + list pane switch
│   └── DesignSystem.swift                     # + code typography token if none fits
├── App/
│   ├── AppContainer.swift                     # wire use case
│   └── PrizmApp.swift                         # "Copy Code" copies generated code
├── PrizmTests/
│   ├── Domain/TOTPSeedParserTests.swift       # NEW
│   ├── Domain/TOTPCodeTests.swift             # NEW
│   ├── Data/TOTPKnownAnswerTests.swift        # NEW (RFC 6238 / 4226 vectors)
│   ├── Data/GenerateTOTPCodeUseCaseTests.swift # NEW
│   ├── Data/VaultRepositoryImplTests.swift    # + index/count/trash cases
│   ├── Presentation/TOTPCodesViewModelTests.swift # NEW
│   └── Mocks/MockPrizmCryptoService.swift     # + hmac
└── UITests/                                   # + verification-codes journey
```

Docs touched: `openspec/specs/copy-menu-commands/spec.md` (Copy Code semantics), `README.md` (roadmap), `SECURITY.md`, `ACCESSIBILITY.md`, changelog.

**Structure Decision**: Follow the existing three-layer layout. Use-case implementations live in `Data/UseCases/`, per the repository convention. The only new Presentation folder is `Vault/VerificationCodes/`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| TOTP codes exempt from the §III UI auto-clear timeout (FR-015) | The requester decided TOTP codes work like other TOTP apps: always visible, with no reveal step and no auto-hide timeout. Why this is acceptable: a code is valid for one period (default 30 s) and is replaced on rotation, so it expires on its own; it is removed on lock, when the app is hidden or minimized, and when no code view is on screen; the copied value still clears from the clipboard in 30 s; the raw seed is never displayed. The exemption covers generated TOTP codes only, never passwords, seeds, or other secrets. | Reveal-on-demand and visible-then-hide were offered and declined. There is no auto-hide preference fallback. Requires a narrow amendment to §III, proposed in tasks.md, and security review at PR time. |
| New `hmac` operation on `PrizmCryptoService` (an actor protocol) | Constitution §III requires all crypto behind that protocol, including HMAC. | A separate Data-layer HMAC helper would be simpler but bypasses the protocol, and breaks the rule that Domain and Presentation never see crypto. The cost is one async hop per code per second, which is negligible. |
| SHA-1 (`Insecure.SHA1`) in HMAC | RFC 6238 default and what nearly all services issue. Without it most real seeds would show "unavailable". | Rejecting SHA-1 would make the feature unusable. HMAC-SHA1 remains secure as a MAC; the known SHA-1 weakness is collision resistance, which HMAC does not rely on. Documented in code and `SECURITY.md`. |
