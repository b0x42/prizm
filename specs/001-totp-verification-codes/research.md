# Research: TOTP Verification Codes

Resolves the open technical questions for [plan.md](plan.md). No `NEEDS CLARIFICATION` items remain.

**Documentation check**: Context7 was queried for Apple's CryptoKit HMAC API (`/apple/swift-crypto`, the open-source mirror of CryptoKit's API). It returned no usable HMAC documentation, so the API usage below comes from existing code in this repo (`PrizmCryptoService.swift:380` already uses `HMAC<SHA256>.authenticationCode(for:using:)`) and training knowledge. Verify `Insecure.SHA1` usage against Apple's documentation at implementation time.

## 1. Where does HMAC live?

- **Decision**: Add a stateless `hmac(algorithm:key:message:)` operation to `PrizmCryptoService`, implemented with CryptoKit. A Domain enum names the algorithm (SHA-1, SHA-256, SHA-512).
- **Rationale**: Constitution §III says all crypto operations go behind `PrizmCryptoService` in the Data layer. The service already uses `HMAC<SHA256>` internally, so the pattern exists.
- **Alternatives**: A standalone Data helper (rejected: bypasses the protocol); a third-party OTP library (rejected: third-party crypto is prohibited without an amendment); hand-rolled HMAC (prohibited).

## 2. Which algorithm and seed forms are supported?

- **Decision**: RFC 6238 TOTP over RFC 4226 truncation. Supported hash algorithms: SHA-1 (default), SHA-256, SHA-512. Digits 6 to 8 (default 6). Period in seconds (default 30), must be positive. Seed forms: a plain base32 secret (case-insensitive, spaces and `=` padding ignored) and an `otpauth://totp/...` link with `secret`, `algorithm`, `digits`, and `period` query parameters.
- **Rationale**: Matches FR-003 and FR-008. Covers what authenticator apps and Bitwarden accept.
- **Rejected inputs (shown as "unavailable")**: Steam-style `steam://` seeds, `otpauth://hotp`, unknown algorithms, digits outside 6 to 8, non-positive period, an empty or invalid base32 secret.
- **Alternatives**: Supporting Steam (out of scope per spec assumptions); silently coercing bad parameters to defaults (rejected: would show wrong codes and break trust).

## 3. How are codes refreshed?

- **Decision**: One `@MainActor` view model, `TOTPCodesViewModel`, owns a refresh loop started from the view's `.task` and cancelled automatically when the view disappears. Each pass reads the clock once and computes a code for every tracked item, then sleeps until the next whole second. The clock is injected (`() -> Date`) so tests control time. The loop stops, and codes are cleared, when the scene is not active.
- **Rationale**: Satisfies FR-002, FR-010, FR-011, and SC-004. A per-view `.task` ties the lifetime to visibility without extra state. One tracker serves both the list and the detail card (Constitution §VI).
- **Alternatives**: `Timer` per row (rejected: many timers, harder to cancel and test); `TimelineView` (rejected: the computation is async because it goes through the crypto actor); Combine publishers (rejected: project style requires async/await).

## 4. How does lock clear codes?

- **Decision**: No new lock hook. `RootViewModel.lockVault()` already clears the vault store and switches screens, which removes the vault browser and cancels its `.task`. The tracker additionally clears its published codes in `onDisappear` and on scene deactivation.
- **Rationale**: Reuses the existing lock path (FR-010, SC-005). A test covers the sequence "codes visible, lock, no codes".
- **Alternatives**: A lock notification observed by the tracker (rejected: redundant).

## 5. How does the list get its items?

- **Decision**: Add `SidebarSelection.verificationCodes`. `VaultRepositoryImpl.buildIndexes()` indexes non-trashed Login items with a non-blank `totp` value, sorted by name with the existing `sorted()` helper, and derives the sidebar count from it. The existing `items(for:)` and `searchItems(query:in:)` then work unchanged.
- **Rationale**: Gives alphabetical order (FR-004a) and trash exclusion (FR-009) for free, and reuses search (FR-004b).
- **Note**: Existing search matches item name, username, and website, which is broader than "by item name". The spec was updated (FR-004b) to say "its current matching rules" so spec and behavior agree.
- **Alternatives**: Filtering in the view model (rejected: duplicates indexing, count, and search logic).
- **Includes items with unusable seeds**: the index checks only that a seed exists, so such items appear with "unavailable" (spec edge case).

## 6. "Copy Code" and seed copy

- **Decision**: `RootViewModel.copySelectedField(.totp)` generates the current code through the use case and copies that, via the existing clipboard path with its 30 s auto-clear. The `.totp` case in `selectedFieldValue` no longer returns the seed. `selectedFieldAvailable(.totp)` is true only when the seed parses. No replacement seed-copy command is added (FR-016).
- **Rationale**: Matches the requester's decision. The raw seed is then never copyable or displayed (FR-017).
- **Follow-up**: Update `openspec/specs/copy-menu-commands/spec.md`, whose scenario "Copy Code copies TOTP seed to clipboard" becomes obsolete.

## 7. Exposure policy under §III

- **Decision**: Codes are always visible while the code view is on screen and the app is active (FR-015, requester's choice). Documented as a justified deviation in plan.md Complexity Tracking, with the fallback of a user-configurable auto-hide if the security review requires it.
- **Rationale**: A code is valid for one period and is not reusable after rotation. The existing app reveals secrets on demand with a 30 s timeout (`EditFieldRow`), so there is precedent for a timeout fallback.

## 8. Accessibility and the expiry cue

- **Decision**: The row exposes one accessibility element: "Verification code for <name>", value the digits spoken individually, plus seconds remaining. No announcement on rotation. The countdown uses `accessibilityAddTraits(.updatesFrequently)`. In the last 5 seconds the indicator changes shape/weight and color together (FR-001a: not color alone).
- **Alternatives**: Announcing each rotation (rejected: floods VoiceOver, FR-014).

## 9. Testing approach

- **Decision**: Known-answer tests from RFC 6238 Appendix B (SHA-1 seed `12345678901234567890`, SHA-256 and SHA-512 seeds, 8 digits, times 59, 1111111109, 1111111111, 1234567890, 2000000000, 20000000000) and RFC 4226 Appendix D (truncation values). Parser tests for each accepted and rejected form. Use-case tests with an injected clock. View model tests for refresh, off-screen stop, and clear-on-lock. Repository tests for index membership (trash, blank seed, non-login). One XCUITest for sidebar to copy.
- **Rationale**: Constitution §IV requires KATs for crypto and test-first.

## 10. Remaining risks

- Seed formats seen in real vaults are unknown; the "unavailable" state bounds the harm.
- Device clock error produces wrong codes; documented as out of scope.
- Cost of one pass for large vaults; measured in the tasks phase, with a threshold in the plan's performance goal.
