## Why

Macwarden is functionally complete for v1 but has no public-facing documentation, no
distribution infrastructure, and no formal statement of scope or security posture. Before
any public release the project needs a README, a SECURITY.md, a changelog, notarization
config, and clear communication of v1 limitations so users can make an informed choice.

## What Changes

- **Add** `README.md` — project overview, feature list, v1 scope (self-hosted only),
  setup/build instructions, known limitations, contributing guide pointer
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

- `project-documentation`: README.md, SECURITY.md — public-facing docs that communicate
  what Macwarden is, what it does, its v1 scope, and its security model
- `release-infrastructure`: Xcode notarization config, hardened runtime verification,
  GitHub Actions release workflow producing a signed and notarized `.dmg`

### Modified Capabilities

_(none — no existing spec-level behavior changes)_

## Impact

- Root directory: new `README.md`, `SECURITY.md`
- `Macwarden/LocalConfig.xcconfig.template` — new file (gitignored instance already expected)
- `Macwarden/Macwarden.xcodeproj` — build settings for notarization / hardened runtime
- `.github/workflows/` — new release CI workflow
- No Domain, Data, or Presentation Swift code changes
