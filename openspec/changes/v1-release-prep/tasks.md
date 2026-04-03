## 1. App Rename (Prizm → Prizm)

- [x] 1.1 Rename `Prizm.xcodeproj` → `Prizm.xcodeproj` and update all internal project file references
- [x] 1.2 Rename Xcode target, scheme, and product name from `Prizm` to `Prizm`
- [x] 1.3 Update bundle ID from `de.b0x42.Prizm` → `de.b0x42.Prizm` and test bundle ID accordingly
- [x] 1.4 Rename `Prizm.entitlements` → `Prizm.entitlements` and update project reference
- [x] 1.5 Update keychain access group in entitlements from `com.prizm` → `com.prizm`
- [x] 1.6 Rename all Swift source files prefixed `Prizm` → `Prizm` (e.g. `PrizmApp.swift` → `PrizmApp.swift`)
- [x] 1.7 Rename all Swift types prefixed `Prizm` → `Prizm` (`PrizmApp`, `PrizmCryptoService`, `PrizmAPIClient`, etc.)
- [x] 1.8 Update all `os.Logger` subsystem strings from `com.prizm` → `com.prizm`
- [x] 1.9 Update all user-visible strings containing "Prizm" (window titles, menu items, error messages)
- [x] 1.10 Update `CLAUDE.md` — replace all Prizm references with Prizm
- [x] 1.11 Update all openspec change files — replace Prizm references with Prizm (including path references in specs and design)
- [x] 1.12 Verify project builds and all tests pass after rename

## 2. App Icon

- [x] 2.1 Export app icon artwork at all required macOS sizes: 16, 32, 64, 128, 256, 512, 1024px (1x and 2x where applicable)
- [x] 2.2 Add all icon images to `Assets.xcassets/AppIcon.appiconset/`
- [x] 2.3 Update `Contents.json` in the appiconset to reference all sizes
- [x] 2.4 Export a 128px PNG to `assets/icon.png` for use in the README
- [x] 2.5 Build and verify the icon appears correctly in Dock, Launchpad, and Finder

## 3. Xcode Project — Release Config

- [x] 3.1 Set `ENABLE_HARDENED_RUNTIME = YES` in the Release build configuration
- [x] 3.2 Build a Release archive locally and verify `codesign --verify --deep` passes — N/A (no paid Developer ID cert)
- [x] 3.3 Check entitlements for any incompatibilities with Hardened Runtime — N/A (no paid Developer ID cert)
- [x] 3.4 Create `Prizm/LocalConfig.xcconfig.template` with `DEVELOPMENT_TEAM = ` placeholder and a comment explaining how to fill it in
- [x] 3.5 Bump `CFBundleShortVersionString` to `1.0.0` and `CFBundleVersion` to `1` in `Info.plist`

## 4. CI / Release Infrastructure

- [x] 4.1 Create `.github/workflows/ci.yml` triggered on push to `main` and on pull requests; steps: checkout, build, run full test suite
- [x] 4.2 Create `ExportOptions.plist` at repo root with `method: developer-id`, bundle ID, and team ID placeholder
- [x] 4.3 Create `.github/workflows/release.yml` triggered on `v*` tags with steps: checkout, import cert into temp keychain, build and archive, export with ExportOptions.plist, create DMG, submit for notarization, staple, create GitHub release with DMG attached
- [x] 4.4 Add a test step to the release workflow that runs the full test suite before archiving; halt on failure
- [x] 4.5 Add cleanup step to release workflow that deletes the temporary keychain on success and failure
- [x] 4.6 Add a fast-fail check at the top of the signing step: if `CERT_P12` secret is empty, exit with a descriptive error message referencing `DEVELOPMENT.md` for setup instructions

## 5. About Window

- [x] 5.1 Write failing tests for `AboutView`: version string reads from `Bundle.main.infoDictionary`, GitHub link URL is correct, all required sections are present (red phase before 5.2)
- [x] 5.2 Create `Presentation/About/AboutView.swift` — custom SwiftUI About window with: app icon, app name, version (read from `Bundle.main`), tagline, clickable GitHub link (`Link` view), "Built with" section (Swift 6.2, open source, auditable), acknowledgements section (Vaultwarden/Bitwarden API, Argon2Swift)
- [x] 5.3 Wire About window into `PrizmApp` — replace default `NSApp.orderFrontStandardAboutPanel` with a SwiftUI window; connect to Prizm → About Prizm menu item
- [x] 5.4 Verify version number in About window matches `CFBundleShortVersionString` in `Info.plist`

## 6. Documentation

- [x] 6.1 Write `README.md` using this exact structure:
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
- [x] 6.2 Write `DEVELOPMENT.md` — prerequisites (Xcode version, macOS 26+), cloning, LocalConfig.xcconfig setup (with note that build fails without it), build command, test command, architecture overview (three-layer), openspec workflow, contributing notes, GitHub secrets documentation for release signing (`CERT_P12`, `CERT_PASSWORD`, `NOTARYTOOL_KEY`, `NOTARYTOOL_KEY_ID`, `NOTARYTOOL_ISSUER_ID`) with description and source for each
- [x] 6.3 Write `SECURITY.md` — threat model, encryption algorithm and key derivation with inline spec references (Argon2id per RFC 9106, EncString per Bitwarden Security Whitepaper), key storage (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), what is and is not protected (explicit out-of-scope threats), vulnerability reporting via GitHub Security Advisories (private disclosure)
- [x] 6.4 Add `CODE_OF_CONDUCT.md` — use the Contributor Covenant v2.1 (industry standard, one page, no customisation needed)
- [x] 6.5 Create `.github/ISSUE_TEMPLATE/bug_report.md` — fields: description, steps to reproduce, expected vs actual behaviour, macOS version, Prizm version, Vaultwarden version
- [x] 6.6 Create `.github/ISSUE_TEMPLATE/feature_request.md` — fields: problem statement, proposed solution, alternatives considered
- [x] 6.7 Create `.github/pull_request_template.md` — sections: what this changes, how to test, checklist (tests pass, no new Macwarden refs, follows Constitution)
- [ ] 6.8 Create `assets/social-preview.png` (1280×640px) — use the screenshot as the base with the Prizm logo and tagline overlaid; set as the GitHub repository social preview image in Settings → Social preview

## 7. Pre-Release Repository Cleanup

- [x] 7.1 Scan for any secrets, credentials, or personal info that should not be public — check all xcconfig files, plists, Swift source, and any config files not covered by .gitignore
- [x] 7.2 Verify `.gitignore` covers all sensitive local files (`LocalConfig.xcconfig`, `*.p12`, `*.mobileprovision`, `.env`, `xcuserdata/`)
- [x] 7.3 Review all TODO/FIXME comments — confirm none reveal exploitable security gaps; acceptable ones should be framed as improvement opportunities, not vulnerabilities
- [x] 7.4 Review open issues and PR descriptions for any private information before the repo goes public
- [ ] 7.5 Enable branch protection on `main`: require at least one PR approval, require CI to pass, disallow direct pushes — configure in GitHub Settings → Branches → Add rule
- [ ] 7.6 Switch repo visibility to public on GitHub — **do this manually after all other tasks are complete**

## 8. Repository Rename

- [x] 8.1 Update GitHub repository About section: description → "Native macOS client for Vaultwarden and self-hosted Bitwarden.", topics → `macos`, `swift`, `swiftui`, `bitwarden`, `vaultwarden`, `password-manager`, `open-source`
- [x] 8.2 Rename the GitHub repository from `macwarden` to `prizm` via GitHub Settings → General → Repository name
- [x] 8.3 Update the git remote URL locally: `git remote set-url origin https://github.com/b0x42/prizm`
- [x] 8.4 Verify push/pull works with the new remote URL

## 9. GitHub Release

- [ ] 9.1 Merge `feat/v1-release-prep` into `main`
- [ ] 9.2 Create GitHub release `v1.0.0` from `main` with user-centric release notes covering all shipped features (not technical commit messages). Features to include:
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

## 10. Screenshot Capture (macOS only)

> **Constraint:** These tasks require a macOS host with Prizm built and runnable. Skip on Linux CI.

- [ ] 10.1 Build a Debug or Release copy of Prizm on macOS and launch it
- [ ] 10.2 Use `screencapture` to capture the main window: get the window ID via `osascript -e 'tell app "Prizm" to id of window 1'`, then run `screencapture -l <windowid> -o assets/screenshot.png`
- [ ] 10.3 Crop / resize the screenshot to a consistent width (e.g. 1200px) if needed
- [ ] 10.4 Commit the screenshot to `assets/screenshot.png` and replace the placeholder in `README.md`

## 11. Verification

- [x] 11.1 Grep for any remaining `Macwarden` or `macwarden` references across all files — must be zero
- [ ] 11.2 Confirm app icon renders correctly at all sizes on a real macOS build
- [x] 11.3 Confirm Release build archives cleanly with Hardened Runtime enabled — N/A (no paid Developer ID cert)
- [ ] 11.4 Confirm README renders correctly on GitHub (centered headline, table, links)
- [x] 11.5 Confirm SECURITY.md satisfies CONSTITUTION §VII checklist (security goal, algorithm + spec ref, deviations, intentional omissions)
- [ ] 11.6 Confirm About window shows correct version, tagline, working GitHub link, and acknowledgements
