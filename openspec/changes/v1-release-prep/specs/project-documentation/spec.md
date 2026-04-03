## ADDED Requirements

### Requirement: README exists and is release-quality
The repository SHALL contain a `README.md` at the root that serves as the primary
landing page for users discovering Prizm on GitHub. It SHALL follow this structure:
app icon → centered headline → badges → one-liner → tagline → screenshot → Why Prizm →
Privacy → Security → Features → Requirements → Install → Roadmap →
Known Limitations → Contributing → Mission & Principles.

#### Scenario: User lands on the GitHub repo
- **WHEN** a user visits the GitHub repository
- **THEN** they see the Prizm app icon centered above the headline, followed by a centered `# Prizm` headline, badges (build status, Swift version, macOS version, license), a one-sentence description ("Native macOS client for Vaultwarden and self-hosted Bitwarden, built in Swift."), and the tagline "Your secrets. Your server. Our user interface."

#### Scenario: User scans badges
- **WHEN** a user glances at the badge row
- **THEN** they can immediately confirm: CI build status, Swift 6.2, macOS 26+, and the license

#### Scenario: User reads Why Prizm
- **WHEN** a user reads the Why Prizm section
- **THEN** they find a direct honest comparison to the official Bitwarden macOS client explaining the Mac Gap (native vs. Electron, macOS conventions, first-class UI)

#### Scenario: User reads the Privacy section
- **WHEN** a user reads the Privacy section
- **THEN** they see a clear statement: no telemetry, no analytics, no cloud — nothing leaves their server

#### Scenario: User reads the Security section
- **WHEN** a user reads the Security section
- **THEN** they find a 3-bullet inline summary (Argon2id KDF per RFC 9106, AES-256-CBC + HMAC-SHA256, keys in macOS Keychain only) and a link to SECURITY.md for the full audit trail

#### Scenario: User reads the feature list
- **WHEN** a user reads the feature list
- **THEN** every item is described in terms of what they can do, not how it is implemented (e.g. "Browse and search your vault" not "NavigationSplitView with VaultBrowserViewModel")

#### Scenario: User reads Requirements
- **WHEN** a user reads the Requirements section
- **THEN** they find: macOS 26+, a self-hosted Vaultwarden or Bitwarden server, and the tested server compatibility (tested against Vaultwarden 1.35.4)

#### Scenario: User wants to install the app
- **WHEN** a user reads the Install section
- **THEN** they find three options: (1) download the unsigned DMG with Gatekeeper bypass instructions and an honest note explaining why it is unsigned, (2) build from source with a single command, (3) link to DEVELOPMENT.md for full build setup

#### Scenario: User reads the roadmap
- **WHEN** a user reads the roadmap table
- **THEN** they see three columns — Now (Touch ID, improved syncing, attachments, folders, TOTP code display), Next (bitwarden.com support, org/collection ciphers, multiple vaults), Later (native macOS autofill)

#### Scenario: User reads Known Limitations
- **WHEN** a user reads the Known Limitations section
- **THEN** they find a direct, honest list: self-hosted only, no bitwarden.com in v1, Safari autofill requires the official Bitwarden app, org/collection ciphers not yet decrypted

#### Scenario: Technical user wants to contribute
- **WHEN** a user reads the Contributing section
- **THEN** they find a link to DEVELOPMENT.md and a brief mention of the openspec workflow

#### Scenario: User reads the mission section
- **WHEN** a user scrolls to the bottom of the README
- **THEN** they find the Mission & Principles section (adapted from the approved draft) as a closing statement

### Requirement: DEVELOPMENT.md exists for contributors
The repository SHALL contain a `DEVELOPMENT.md` at the root covering everything a
contributor needs to build and run the project locally.

#### Scenario: New contributor sets up the project
- **WHEN** a contributor reads `DEVELOPMENT.md`
- **THEN** they find: prerequisites (Xcode version, macOS 26+), how to copy `LocalConfig.xcconfig.template` and fill in their Team ID (build fails without it), build and test commands, architecture overview, and a link to the openspec workflow

#### Scenario: Maintainer sets up release signing
- **WHEN** a maintainer reads `DEVELOPMENT.md`
- **THEN** they find the five required GitHub secrets documented (`CERT_P12`, `CERT_PASSWORD`, `NOTARYTOOL_KEY`, `NOTARYTOOL_KEY_ID`, `NOTARYTOOL_ISSUER_ID`) with a description of each and where to obtain the values

#### Scenario: Contributor runs tests
- **WHEN** a contributor follows the test instructions in `DEVELOPMENT.md`
- **THEN** they can run the full test suite with a single `xcodebuild test` command

### Requirement: SECURITY.md exists and documents the threat model
The repository SHALL contain a `SECURITY.md` at the root satisfying CONSTITUTION §VII
(Radical Transparency).

#### Scenario: User audits encryption approach
- **WHEN** a technically literate user reads `SECURITY.md`
- **THEN** they can independently verify what data is encrypted, which algorithm is used (with inline spec references: RFC 9106 for Argon2id, Bitwarden Security Whitepaper for EncString), and where keys are stored

#### Scenario: User reads what the app does not protect against
- **WHEN** a user reads `SECURITY.md`
- **THEN** they find an explicit list of out-of-scope threats (e.g. physical access, malicious apps with full disk access, compromised self-hosted server)

#### Scenario: User wants to report a vulnerability
- **WHEN** a user reads `SECURITY.md`
- **THEN** they find a clear instruction to report via GitHub Security Advisories (private disclosure) on the repository

### Requirement: About window shows app identity and acknowledgements
The app SHALL show a custom SwiftUI About window (replacing the default macOS About panel)
containing: app name, version, tagline, clickable GitHub repository link, "Built with"
section (Swift 6.2, open source, auditable), and acknowledgements (Vaultwarden/Bitwarden
API, Argon2Swift). No copyright line. Accessible via Prizm → About Prizm menu item.

#### Scenario: User opens About Prizm
- **WHEN** a user selects Prizm → About Prizm from the menu bar
- **THEN** a window appears showing the app name, current version, tagline ("Your secrets. Your server. Our user interface."), a clickable link to the GitHub repository, the "Built with" section, and acknowledgements

#### Scenario: User clicks the GitHub link
- **WHEN** a user clicks the GitHub repository link in the About window
- **THEN** the link opens in the default browser

#### Scenario: Version reflects the current build
- **WHEN** the About window is shown
- **THEN** the version number matches the value in `Info.plist` (CFBundleShortVersionString + CFBundleVersion)

### Requirement: GitHub repository About section reflects Prizm
The GitHub repository About section (description, website, topics) SHALL be updated
to reflect the Prizm identity. Description: "Native macOS client for Vaultwarden and
self-hosted Bitwarden." Topics: `macos`, `swift`, `swiftui`, `bitwarden`, `vaultwarden`,
`password-manager`, `open-source`.

#### Scenario: User lands on the GitHub repo page
- **WHEN** a user visits the repository on GitHub
- **THEN** the About section shows the Prizm description and relevant topics, not the old Macwarden text

### Requirement: GitHub repository is renamed to match the app name
The GitHub repository SHALL be renamed from `macwarden` to `prizm` and the local git
remote URL SHALL be updated to match. All existing GitHub links (issues, PRs, stars)
are automatically forwarded by GitHub after a rename.

#### Scenario: Repository is renamed
- **WHEN** the repository is renamed on GitHub
- **THEN** the remote URL `https://github.com/b0x42/prizm` is reachable and push/pull works

#### Scenario: Local remote is updated
- **WHEN** the local remote URL is updated
- **THEN** `git remote get-url origin` returns `https://github.com/b0x42/prizm`

### Requirement: README screenshot is a real app capture (macOS only)
The screenshot in `README.md` SHALL be an actual capture of the running Prizm app, not
a placeholder. Capture is automated via `screencapture` on macOS and committed to
`assets/screenshot.png`. The app icon PNG for the README header is stored at `assets/icon.png`.
This task MUST be run on a macOS host — it cannot be automated on Linux.

#### Scenario: User sees a screenshot in the README
- **WHEN** a user visits the GitHub repository
- **THEN** the screenshot shows the real Prizm UI (vault list + detail pane), not a placeholder image

#### Scenario: Screenshot is captured automatically
- **WHEN** this task is executed on macOS
- **THEN** Prizm is launched, the main window ID is retrieved via AppleScript, `screencapture -l` captures it losslessly, and the result is saved to `assets/screenshot.png`

### Requirement: LocalConfig.xcconfig.template exists
The repository SHALL contain `Prizm/LocalConfig.xcconfig.template` so contributors
can onboard without reading CLAUDE.md to discover the required file.

#### Scenario: Contributor clones the repo and tries to build
- **WHEN** a contributor follows `DEVELOPMENT.md` setup steps
- **THEN** they copy the template, fill in their Team ID, and the project builds without further configuration
