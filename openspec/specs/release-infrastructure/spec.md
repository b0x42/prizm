
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

### Requirement: CI workflow runs build and tests on every push and PR
The repository SHALL contain `.github/workflows/ci.yml` that triggers on push to `main`
and on all pull requests. It SHALL build the project and run the full test suite.
The workflow provides the build status badge shown in the README.

#### Scenario: Pull request is opened
- **WHEN** a pull request is opened or updated
- **THEN** the CI workflow runs, builds the project, and runs all tests; a failing build blocks merge

#### Scenario: Push to main
- **WHEN** a commit is pushed to `main`
- **THEN** the CI workflow runs and the build badge reflects the current status

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

### Requirement: Release workflow fails fast with a clear message when secrets are absent
The `.github/workflows/release.yml` SHALL include a fast-fail check at the top of the
signing step: if the `CERT_P12` secret is empty, the step SHALL exit immediately with a
human-readable error message pointing to `DEVELOPMENT.md` for setup instructions.

#### Scenario: Workflow runs without secrets configured
- **WHEN** a fork or fresh clone pushes a `v*` tag without secrets configured
- **THEN** the signing step exits immediately with a clear message (e.g. "CERT_P12 secret is not set — see DEVELOPMENT.md for release signing setup") rather than a cryptic keychain or codesign error
