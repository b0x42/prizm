## ADDED Requirements

### Requirement: App icon is present at all required sizes
The app SHALL have an icon defined in `Assets.xcassets/AppIcon.appiconset` at all
sizes required by macOS (16, 32, 64, 128, 256, 512, 1024px).

#### Scenario: App is launched
- **WHEN** a user launches Prizm
- **THEN** the app icon appears correctly in the Dock, Launchpad, and Finder at all display scales

#### Scenario: App icon appears in Finder
- **WHEN** a user views the `.app` bundle in Finder
- **THEN** the icon renders at the correct resolution without falling back to a generic placeholder

### Requirement: Hardened Runtime is enabled for Release builds
The Xcode project SHALL have `ENABLE_HARDENED_RUNTIME = YES` in the Release build
configuration, as required by Apple for notarization.

#### Scenario: Release archive is built
- **WHEN** `xcodebuild archive` runs with the Release configuration
- **THEN** the resulting `.app` has the hardened runtime entitlement set and passes `codesign --verify --deep`

### Requirement: ExportOptions.plist exists for Developer ID distribution
The repository SHALL contain an `ExportOptions.plist` at the root configured for
`method: developer-id`, enabling `xcodebuild -exportArchive` to produce a
Developer ID-signed app without interactive prompts.

#### Scenario: CI exports the archive
- **WHEN** the release workflow runs `xcodebuild -exportArchive`
- **THEN** it uses `ExportOptions.plist` and produces a `.app` signed with the Developer ID Application identity

### Requirement: GitHub Actions release workflow produces a DMG on version tags
The repository SHALL contain `.github/workflows/release.yml` that triggers on `v*`
tags and produces a signed, notarized, stapled `.dmg` attached to a GitHub release.

#### Scenario: Developer pushes a version tag
- **WHEN** a tag matching `v*` is pushed to the repository
- **THEN** the workflow runs: imports the Developer ID certificate, builds and archives, exports, creates a `.dmg`, submits for notarization, staples the ticket, and creates a GitHub release with the `.dmg` attached

#### Scenario: Secrets are not yet configured
- **WHEN** the workflow runs without the required GitHub secrets populated
- **THEN** the signing and notarization steps fail with a clear error; no broken artifact is published

#### Scenario: Tests fail during the release build
- **WHEN** the test step fails
- **THEN** the workflow halts before producing any artifact and the release is not created

### Requirement: Release workflow has a prominent comment when secrets are absent
The `.github/workflows/release.yml` SHALL include a comment block at the top of the
signing and notarization steps explaining that these steps are no-ops without the
required GitHub secrets, and pointing to `DEVELOPMENT.md` for setup instructions.

#### Scenario: Workflow runs without secrets configured
- **WHEN** a fork or fresh clone runs the workflow without secrets
- **THEN** the signing step fails with a descriptive error referencing the comment and `DEVELOPMENT.md`, not a cryptic keychain or codesign error
