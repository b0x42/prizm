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
- **Modify** `Macwarden.xcodeproj` — wire notarization and hardened runtime settings for
  distribution builds; verify App Sandbox entitlements are correct
- **Add** `.github/workflows/release.yml` — CI workflow: build, test, notarize, staple,
  create GitHub release with `.dmg` artifact

## Capabilities

### New Capabilities

- `project-documentation`: README.md (release-facing, user-centric), DEVELOPMENT.md
  (contributor/builder guide, split out of README), SECURITY.md — together these communicate
  what Macwarden is, what users can do with it, how to build it, and its security model
- `release-infrastructure`: Xcode notarization config, hardened runtime verification,
  GitHub Actions release workflow producing a signed and notarized `.dmg`

### Modified Capabilities

_(none — no existing spec-level behavior changes)_

## Impact

- Root directory: new `README.md`, `DEVELOPMENT.md`, `SECURITY.md`
- `Macwarden/LocalConfig.xcconfig.template` — new file (gitignored instance already expected)
- `Macwarden/Macwarden.xcodeproj` — build settings for notarization / hardened runtime
- `.github/workflows/` — new release CI workflow
- No Domain, Data, or Presentation Swift code changes
