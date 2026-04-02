## 1. App Rename (Macwarden → Prizm)

- [ ] 1.1 Rename `Macwarden.xcodeproj` → `Prizm.xcodeproj` and update all internal project file references
- [ ] 1.2 Rename Xcode target, scheme, and product name from `Macwarden` to `Prizm`
- [ ] 1.3 Update bundle ID from `de.b0x42.Macwarden` → `de.b0x42.Prizm` and test bundle ID accordingly
- [ ] 1.4 Rename `Macwarden.entitlements` → `Prizm.entitlements` and update project reference
- [ ] 1.5 Update keychain access group in entitlements from `com.macwarden` → `com.prizm`
- [ ] 1.6 Rename all Swift source files prefixed `Macwarden` → `Prizm` (e.g. `MacwardenApp.swift` → `PrizmApp.swift`)
- [ ] 1.7 Rename all Swift types prefixed `Macwarden` → `Prizm` (`MacwardenApp`, `MacwardenCryptoService`, `MacwardenAPIClient`, etc.)
- [ ] 1.8 Update all `os.Logger` subsystem strings from `com.macwarden` → `com.prizm`
- [ ] 1.9 Update all user-visible strings containing "Macwarden" (window titles, menu items, error messages)
- [ ] 1.10 Update `CLAUDE.md` — replace all Macwarden references with Prizm
- [ ] 1.11 Update all openspec change files — replace Macwarden references with Prizm (including path references in specs and design)
- [ ] 1.12 Verify project builds and all tests pass after rename

## 2. App Icon

- [ ] 2.1 Export app icon artwork at all required macOS sizes: 16, 32, 64, 128, 256, 512, 1024px (1x and 2x where applicable)
- [ ] 2.2 Add all icon images to `Assets.xcassets/AppIcon.appiconset/`
- [ ] 2.3 Update `Contents.json` in the appiconset to reference all sizes
- [ ] 2.4 Build and verify the icon appears correctly in Dock, Launchpad, and Finder

## 3. Xcode Project — Release Config

- [ ] 3.1 Set `ENABLE_HARDENED_RUNTIME = YES` in the Release build configuration
- [ ] 3.2 Build a Release archive locally and verify `codesign --verify --deep` passes
- [ ] 3.3 Check entitlements for any incompatibilities with Hardened Runtime; add missing entitlement flags if needed
- [ ] 3.4 Create `Prizm/LocalConfig.xcconfig.template` with `DEVELOPMENT_TEAM = ` placeholder and a comment explaining how to fill it in

## 4. CI / Release Infrastructure

- [ ] 4.1 Create `.github/workflows/ci.yml` triggered on push to `main` and on pull requests; steps: checkout, build, run full test suite
- [ ] 4.2 Create `ExportOptions.plist` at repo root with `method: developer-id`, bundle ID, and team ID placeholder
- [ ] 4.3 Create `.github/workflows/release.yml` triggered on `v*` tags with steps: checkout, import cert into temp keychain, build and archive, export with ExportOptions.plist, create DMG, submit for notarization, staple, create GitHub release with DMG attached
- [ ] 4.4 Add a test step to the release workflow that runs the full test suite before archiving; halt on failure
- [ ] 4.5 Add cleanup step to release workflow that deletes the temporary keychain on success and failure
- [ ] 4.6 Add a fast-fail check at the top of the signing step: if `CERT_P12` secret is empty, exit with a descriptive error message referencing `DEVELOPMENT.md` for setup instructions

## 5. About Window

- [ ] 5.1 Create `Presentation/About/AboutView.swift` — custom SwiftUI About window with: app icon, app name, version (read from `Bundle.main`), tagline, clickable GitHub link (`Link` view), "Built with" section (Swift 6.2, open source, auditable), acknowledgements section (Vaultwarden/Bitwarden API, Argon2Swift)
- [ ] 5.2 Wire About window into `MacwardenApp` (post-rename: `PrizmApp`) — replace default `NSApp.orderFrontStandardAboutPanel` with a SwiftUI window; connect to Prizm → About Prizm menu item
- [ ] 5.3 Verify version number in About window matches `CFBundleShortVersionString` in `Info.plist`

## 6. Documentation

- [ ] 6.1 Write `README.md` using this exact structure:
  1. Centered `# Prizm` headline
  2. Badge row: CI build status, Swift 6.2, macOS 26+, license
  3. One-liner: "Native macOS client for Vaultwarden and self-hosted Bitwarden, built in Swift."
  4. Tagline: "Your secrets. Your server. Our user interface."
  5. Screenshot placeholder
  6. **Why Prizm** — Mac Gap framing, honest comparison to official Bitwarden client (native vs. Electron)
  7. **Privacy** — no telemetry, no analytics, no cloud; nothing leaves your server
  8. **Security** — 3-bullet inline summary (Argon2id RFC 9106, AES-256-CBC + HMAC-SHA256, macOS Keychain) + link to SECURITY.md
  9. **Features** — user-centric list (what you can do, not how it works)
  10. **Requirements** — macOS 26+, self-hosted Vaultwarden or Bitwarden; note tested against Vaultwarden 1.35.4
  11. **Install** — (a) unsigned DMG + Gatekeeper bypass with honest explanation of why it is unsigned, (b) build from source one-liner, (c) link to DEVELOPMENT.md
  12. **Roadmap** — Now/Next/Later table
  13. **Known Limitations** — direct honest list
  14. **Contributing** — link to DEVELOPMENT.md, mention openspec workflow
  15. **Mission & Principles** — adapted from approved draft (closing statement)
- [ ] 6.2 Write `DEVELOPMENT.md` — prerequisites (Xcode version, macOS 26+), cloning, LocalConfig.xcconfig setup (with note that build fails without it), build command, test command, architecture overview (three-layer), openspec workflow, contributing notes, GitHub secrets documentation for release signing (`CERT_P12`, `CERT_PASSWORD`, `NOTARYTOOL_KEY`, `NOTARYTOOL_KEY_ID`, `NOTARYTOOL_ISSUER_ID`) with description and source for each
- [ ] 6.3 Write `SECURITY.md` — threat model, encryption algorithm and key derivation with inline spec references (Argon2id per RFC 9106, EncString per Bitwarden Security Whitepaper), key storage (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), what is and is not protected (explicit out-of-scope threats), vulnerability reporting via GitHub Security Advisories (private disclosure)

## 7. Repository Rename

- [ ] 7.1 Rename the GitHub repository from `macwarden` to `prizm` via GitHub Settings → General → Repository name
- [ ] 7.2 Update the git remote URL locally: `git remote set-url origin https://github.com/b0x42/prizm`
- [ ] 7.3 Verify push/pull works with the new remote URL

## 8. GitHub Release

- [ ] 8.1 Merge `feat/v1-release-prep` into `main`
- [ ] 8.2 Create GitHub release `v1.0.0` from `main` with user-centric release notes covering all shipped features (not technical commit messages). Features to include:
  - Browse, search, and manage your entire vault
  - View all item types: logins, cards, identities, secure notes, SSH keys
  - Create, edit, and delete vault items
  - Soft delete with Trash and permanent delete
  - Restore items from Trash
  - Star items as favourites
  - Generate strong passwords and passphrases
  - Copy username, password, TOTP code, and website with one click
  - Reveal masked fields by holding Option
  - Global search across all vault items (⌘F) with match highlighting
  - Lock vault with ⌘L; auto-locks on sleep and screensaver
  - Sync status indicator in sidebar
  - Alphabetical sections in item list
  - Keyboard shortcut ⌘N for new item

## 9. Verification

- [ ] 9.1 Grep for any remaining `Macwarden` or `macwarden` references across all files — must be zero
- [ ] 9.2 Confirm app icon renders correctly at all sizes on a real macOS build
- [ ] 9.3 Confirm Release build archives cleanly with Hardened Runtime enabled
- [ ] 9.4 Confirm README renders correctly on GitHub (centered headline, table, links)
- [ ] 9.5 Confirm SECURITY.md satisfies CONSTITUTION §VII checklist (security goal, algorithm + spec ref, deviations, intentional omissions)
- [ ] 9.6 Confirm About window shows correct version, tagline, working GitHub link, and acknowledgements
