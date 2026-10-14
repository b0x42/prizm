# Quickstart: Validate TOTP Verification Codes

A validation guide, not an implementation guide. See [contracts/](contracts/) and [data-model.md](data-model.md) for details.

## Prerequisites

- Ask the user for their Apple Developer Team ID before building (see `DEVELOPMENT.md`); `Prizm/LocalConfig.xcconfig` must contain `DEVELOPMENT_TEAM`.
- A test vault on a self-hosted Bitwarden or Vaultwarden server with at least:
  - Three Login items with seeds: one plain base32, one `otpauth://` link with `digits=8&period=60&algorithm=SHA256`, and one extra.
  - One Login item with an invalid seed (for example `not-a-seed!`).
  - One Login item with a seed that is in the trash.
  - One Login item with no seed.
- A reference authenticator (any standards-conforming app) loaded with the same seeds.

## Automated checks

```bash
# Unit + integration tests (known-answer vectors, parser, use case, view model, repository)
xcodebuild test \
  -project "Prizm/Prizm.xcodeproj" \
  -scheme "Prizm" \
  -destination "platform=macOS"
```

Expected: all pass, including the RFC 6238 Appendix B vectors for SHA-1, SHA-256, and SHA-512, and the RFC 4226 truncation vectors.

## Manual scenarios

1. **Per-item code (Story 1, SC-001)**
   Open a Login with a seed. Expect a "Verification Code" card with a grouped code and a countdown. Compare with the reference authenticator across at least 3 rotations. Codes must match each time.
2. **Rotation (FR-002, SC-004)**
   Watch the countdown reach 0. Expect the new code within 1 second, with no user action.
3. **Expiry cue (FR-001a)**
   In the last 5 seconds, the indicator changes shape/weight as well as color. Check with a grayscale display filter.
4. **Copy (FR-006, SC-006)**
   Click the copy button, paste into a text field: no space in the pasted value. Wait 30 seconds, paste again: the code is gone.
5. **Copy Code menu (FR-016)**
   Select a Login with a seed and press ⌃⌘C. The generated code is on the clipboard, not the seed. Select an item with no seed: the command is disabled. Confirm no menu item copies the raw seed.
6. **List (Story 2, FR-004 to FR-009)**
   Select "Verification Codes". Expect exactly the non-trashed items with seeds (including the invalid one), alphabetical, each with a code or "Code unavailable". The trashed item is absent. The sidebar count matches.
7. **Search (FR-004b)**
   Type part of an item name. The list filters. Clear the search: all rows return.
8. **Select row (FR-007)**
   Click a row. The item opens in the detail pane.
9. **Empty state (Story 2 scenario 5)**
   In a vault with no seeds, the list shows the empty state.
10. **Lock (Story 3, SC-005)**
    With codes visible, lock the vault. No code is visible on the unlock screen. Unlock: codes shown are current.
11. **Inactive window (edge case)**
    Switch to another app for over a period, then back. The codes shown are current. While away, no refresh work runs (check Activity Monitor CPU stays idle).
12. **VoiceOver (FR-014, Constitution §VIII)**
    Focus a row: "Verification code for <name>", digits spoken individually, seconds remaining. Leave focus on it across a rotation: no repeated announcement.
13. **Logs (FR-012)**
    Run `log stream --predicate 'subsystem == "com.prizm"' --level debug` while using the feature. No seed or code appears.
14. **Sign-in (SC-007)**
    Sign in to a real TOTP-protected service using only a code from Prizm.

## Exit criteria

All automated tests pass, scenarios 1 to 14 behave as described, and the security review (Constitution §III) signs off on the always-visible exposure deviation recorded in `plan.md`.
