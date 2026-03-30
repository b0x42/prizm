## Why

Macwarden is functionally complete for v1 but has no public-facing documentation, no
distribution infrastructure, and no formal statement of scope or security posture. Before
any public release the project needs a README, a SECURITY.md, a changelog, notarization
config, and clear communication of v1 limitations so users can make an informed choice.

## What Changes

- **Add** `README.md` — polished release-facing document: centered headline and tagline,
  screenshot/demo, user-centric feature list (what users can do, not how it works
  technically), v1 scope (self-hosted only), quick install instructions, known limitations,
  links to further docs, and a roadmap table (Now / Next / Later). Development/build
  details are NOT in the README — they live in `DEVELOPMENT.md`.

  Roadmap:
  | Now | Next | Later |
  |-----|------|-------|
  | Touch ID unlock | bitwarden.com account support | Native macOS autofill |
  | Improved syncing (background, non-blocking) | Org/collection cipher support | |
  | Attachments | Multiple vaults | |
  | Folders | | |
  | TOTP code display | | |
- **Add** `DEVELOPMENT.md` — everything aimed at contributors and builders: build commands,
  Xcode setup, Team ID config, architecture overview, test instructions, openspec workflow
- **Add** `SECURITY.md` — threat model, encryption summary, key storage, what the app
  does and does not protect against (required by CONSTITUTION §VII)
- **Add** `Macwarden/LocalConfig.xcconfig.template` — Team ID template (already referenced
  in CLAUDE.md but not yet created)
- **Modify** `Macwarden.xcodeproj` — enable `ENABLE_HARDENED_RUNTIME = YES` for Release;
  verify App Sandbox entitlements are correct for distribution
- **Add** `ExportOptions.plist` — tells `xcodebuild -exportArchive` to sign with Developer
  ID (method: developer-id); committed to repo, contains no secrets
- **Add** `.github/workflows/release.yml` — triggered on `v*` tags; imports Developer ID
  certificate into a temporary keychain, archives, exports, creates DMG, submits to Apple
  notarization, staples ticket, and publishes a GitHub release with the `.dmg` attached.
  All secrets (certificate, notarization API key) live in GitHub repo secrets — nothing
  sensitive is committed. **Requires a paid Apple Developer account ($99/year)** — without
  one, signing and notarization steps will fail. The workflow is built out regardless; it
  activates once the secrets are populated. Until then, README documents a manual Gatekeeper
  bypass for technical users (`xattr -d com.apple.quarantine Macwarden.app`) and a
  build-from-source path as the v1 distribution fallback. Required secrets:
  - `CERT_P12` — Developer ID cert exported as base64-encoded .p12
  - `CERT_PASSWORD` — .p12 export password
  - `NOTARYTOOL_KEY` — App Store Connect API key (.p8) as base64
  - `NOTARYTOOL_KEY_ID` — API key ID
  - `NOTARYTOOL_ISSUER_ID` — Issuer ID from App Store Connect

## Capabilities

### New Capabilities

- `project-documentation`: README.md (release-facing, user-centric), DEVELOPMENT.md
  (contributor/builder guide, split out of README), SECURITY.md — together these communicate
  what Macwarden is, what users can do with it, how to build it, and its security model
- `release-infrastructure`: Hardened Runtime + App Sandbox config, `ExportOptions.plist`,
  GitHub Actions workflow that signs, notarizes, staples, and publishes a `.dmg` on every
  `v*` tag; signing secrets managed via GitHub repo secrets

### Modified Capabilities

_(none — no existing spec-level behavior changes)_

## Impact

- Root directory: new `README.md`, `DEVELOPMENT.md`, `SECURITY.md`
- `Macwarden/LocalConfig.xcconfig.template` — new file (gitignored instance already expected)
- `Macwarden/Macwarden.xcodeproj` — `ENABLE_HARDENED_RUNTIME = YES` in Release config
- `ExportOptions.plist` — new file at repo root, no secrets
- `.github/workflows/release.yml` — new release CI workflow
- No Domain, Data, or Presentation Swift code changes
