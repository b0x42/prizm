## Context

Prizm (formerly Prizm) is functionally complete for v1 but ships with no public-facing
documentation, no app icon, and no distribution pipeline. The codebase targets self-hosted
Bitwarden/Vaultwarden servers only. Distribution is via GitHub releases (direct `.dmg`
download) — not the Mac App Store.

Current state:
- No `README.md`, `SECURITY.md`, or `DEVELOPMENT.md` exist
- No app icon in `Assets.xcassets/AppIcon.appiconset`
- `ENABLE_HARDENED_RUNTIME` is not set in the Xcode project
- No `ExportOptions.plist` or GitHub Actions release workflow
- `LocalConfig.xcconfig.template` is referenced in CLAUDE.md but does not exist on disk
- No paid Apple Developer account; unsigned distribution is the definitive v1 path.
  README documents the Gatekeeper bypass and build-from-source as the install options.

## Goals / Non-Goals

**Goals:**
- Write a polished, release-quality `README.md` with centered headline/tagline,
  user-centric feature list, roadmap table, install instructions, and known limitations
- Write `DEVELOPMENT.md` covering everything contributors need: build setup, Team ID
  config, architecture overview, test instructions, openspec workflow
- Write `SECURITY.md` documenting threat model, encryption, key storage, and explicit
  non-protections (satisfies CONSTITUTION §VII)
- Add app icon at all required macOS sizes to the asset catalogue
- Create `LocalConfig.xcconfig.template` so new contributors can onboard without hunting
  for the required field
- Enable Hardened Runtime in the Release build configuration (required for notarization)
- Add `ExportOptions.plist` for Developer ID distribution
- Add `.github/workflows/release.yml` that produces a signed, notarized, stapled `.dmg`
  on every `v*` tag push

**Non-Goals:**
- App Store distribution — this is GitHub-only
- Implementing any new app features (rename, autofill, Touch ID, etc.)
- Bitwarden.com account support — self-hosted only in v1
- Automated screenshot generation for the README

## Decisions

### D1 — README structure: user-facing only, link out for dev content
Split documentation into `README.md` (users) and `DEVELOPMENT.md` (contributors).
The README must not require any Swift or Xcode knowledge to understand.

Alternatives considered:
- Single README with collapsible sections — GitHub renders these poorly on mobile and
  buries the user-facing content under technical noise.
- Wiki — adds friction; contributors expect `DEVELOPMENT.md` in the repo root.

### D2 — GitHub Actions: certificate imported into ephemeral keychain per run
The Developer ID `.p12` is stored as a base64 GitHub secret, decoded and imported into
a temporary keychain created for each CI run, then deleted on teardown. This is the
standard pattern for macOS signing in CI and avoids leaving credentials in the runner.

Alternatives considered:
- Self-hosted runner with persistent keychain — adds infrastructure burden and a
  persistent credential surface, worse security posture than ephemeral secrets.

### D3 — Notarization via App Store Connect API key (not Apple ID + password)
API key auth (`notarytool --key`) is preferred over Apple ID + password because it
does not require an app-specific password, is not rate-limited by two-factor auth
prompts, and is the approach Apple now recommends for CI.

### D4 — Gatekeeper bypass documented in README for unsigned v1
Until a paid Developer ID certificate is obtained, the README will document both a
manual bypass (`xattr -d com.apple.quarantine Prizm.app`) and a build-from-source
path. This is acceptable for a self-hosted tool targeting technical users.

### D5 — `ExportOptions.plist` committed to repo
Contains no secrets (method, bundle ID, team ID only). Committing it keeps the CI
workflow readable and ensures local archive exports use the same settings as CI.

## Risks / Trade-offs

- **Unsigned distribution UX** → Gatekeeper blocks the app on first launch without
  the Developer ID certificate. Mitigated by clear README instructions for the bypass.
  Risk disappears once the paid account is set up and secrets are populated.

- **Hardened Runtime entitlement gaps** → Enabling Hardened Runtime may surface
  entitlement violations that were silently permitted in development builds (e.g. JIT,
  unsigned executable memory). Mitigation: run a Release build locally and verify before
  merging; add any missing entitlements to `Prizm.entitlements`.

- **App icon sizes** → macOS requires specific sizes in the appiconset (16, 32, 64, 128,
  256, 512, 1024px). Missing sizes produce warnings or a blank icon at some scales.
  Mitigation: generate all sizes from the master artwork before adding to the catalogue.

## Open Questions

~~Q1~~ **Resolved**: No paid Apple Developer account for v1. Unsigned distribution is the
definitive path; README documents the Gatekeeper bypass and build-from-source.

~~Q2~~ **Resolved**: Tagline is *"Your secrets. Your server. Our user interface."*

~~Q3~~ **Resolved**: README will include a screenshot placeholder; real screenshots to be
added before the v1 tag.
