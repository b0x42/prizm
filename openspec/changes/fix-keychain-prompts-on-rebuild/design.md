## Context

macOS offers two keychain stacks:

1. **Login keychain** (legacy) — items have per-item ACLs tied to the code-signature hash of the writing process. Every new build gets a new hash → macOS prompts for each stored item.
2. **Data protection keychain** (modern) — access is controlled by the `keychain-access-groups` entitlement. Any binary signed with the same Team ID and the matching entitlement can access items without a prompt.

The app currently uses the login keychain. With 8 keychain items stored across a session (activeUserId, email, name, encUserKey, kdfParams, serverEnvironment, accessToken, refreshToken, plus deviceIdentifier), this produces 4 prompts on startup and up to 9 on unlock with every new build.

The entitlements file currently has `com.apple.security.app-sandbox` and `com.apple.security.network.client` but no `keychain-access-groups`, which is required to opt into the data protection keychain path.

## Goals / Non-Goals

**Goals:**
- Eliminate keychain password prompts when running a new debug build
- Keep the Team ID (and therefore developer identity) out of the committed repo
- Fix the redundant keychain reads in `unlockWithPassword` while we're touching that code

**Non-Goals:**
- Migrating existing login-keychain items automatically (one-time sign-out is acceptable)
- Changing what data is stored or the security properties of the stored data
- Supporting unsigned / ad-hoc builds without a Team ID (Xcode automatic signing is required)

## Decisions

### Decision 1: Data protection keychain via entitlement

Add `keychain-access-groups` to the entitlements file using the `$(AppIdentifierPrefix)` macro:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.macwarden</string>
</array>
```

Add `kSecUseDataProtectionKeychain: true` to `baseQuery(for:)` in `KeychainServiceImpl`. This is the only place keychain attributes are assembled, so a single change covers all read/write/delete operations. Do NOT add `kSecAttrAccessGroup` as a hardcoded Swift string — for sandboxed apps, the system automatically uses the first entry in the `keychain-access-groups` entitlement as the access group. Setting it explicitly would require embedding the resolved Team ID in source code, defeating the purpose of the xcconfig approach.

**Why not per-query patching?** `baseQuery` is the single source of truth for all queries. Patching each call site separately would be error-prone and inconsistent.

**Alternative considered — consolidate items into one blob:** Reduces prompts from N to 1 but doesn't eliminate them. Rejected because it solves the symptom, not the cause.

**Alternative considered — `#if DEBUG` UserDefaults escape hatch:** Diverges debug and release code paths, meaning the keychain path is untested during development. Rejected.

### Decision 2: xcconfig for Team ID

Create `LocalConfig.xcconfig` (gitignored) and `LocalConfig.xcconfig.template` (committed). The project reads `DEVELOPMENT_TEAM` from the xcconfig. Each developer fills in their own Team ID locally.

**Why xcconfig over `.env` or a script?** xcconfig is Xcode-native — no build phase scripting needed, Xcode resolves it automatically during code signing.

**What about CI?** CI can set `DEVELOPMENT_TEAM` as a build setting override appended to the `xcodebuild` command: `xcodebuild ... DEVELOPMENT_TEAM=ABCDE12345`. (Note: `-D` prefix is for C preprocessor defines — build setting overrides have no prefix.) Alternatively, CI can inject a secrets-populated xcconfig. No change needed in the committed files.

### Decision 3: Fix duplicate keychain reads in `unlockWithPassword`

`unlockWithPassword` reads `email`, `name`, and `serverEnvironment` directly, then calls `account(for:)` which reads them again. Refactor to call `account(for:)` once and reuse the result.

**Why now?** We're already touching the unlock path to verify the data protection keychain migration. Fixing this saves 1 read: 9 → 8. Only `email` is duplicated — `kdfParams` and `encUserKey` are not returned by `account(for:)` and must still be read directly. The full saving only matters before the entitlement change lands; afterwards prompts are gone entirely.

## Risks / Trade-offs

**One-time sign-out required** → Existing login-keychain items are not readable via the data protection keychain path and will return `errSecItemNotFound`. The app will show the login screen as if no account is stored. Users (and the developer during testing) need to sign in once after the change. Mitigation: log a clear message so it's not confusing.

**Free Apple ID personal team** → The `$(AppIdentifierPrefix)` macro resolves correctly for personal teams in Xcode. No paid account needed for local development. Mitigation: document in template.

**kSecUseDataProtectionKeychain on macOS 13** → Apple's own documentation and developer reports confirm this attribute is safe on macOS 13+ for sandboxed apps with the keychain-access-groups entitlement. The concern noted in CLAUDE.md (per-item prompts) applies when the entitlement is absent; with the entitlement present it behaves correctly.

## Migration Plan

1. Apply code changes (entitlements, KeychainService, AuthRepositoryImpl, xcconfig)
2. Delete existing keychain items for `com.macwarden` service (or sign out before upgrading)
3. Sign in once — items are written to data protection keychain
4. Subsequent rebuilds: no prompts
