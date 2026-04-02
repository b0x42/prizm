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

## 4. Release Infrastructure

- [ ] 4.1 Create `ExportOptions.plist` at repo root with `method: developer-id`, bundle ID, and team ID placeholder
- [ ] 4.2 Create `.github/workflows/release.yml` triggered on `v*` tags with steps: checkout, import cert into temp keychain, build and archive, export with ExportOptions.plist, create DMG, submit for notarization, staple, create GitHub release with DMG attached
- [ ] 4.5 Add a prominent comment block to the signing and notarization steps in the workflow explaining they are no-ops without secrets and pointing to `DEVELOPMENT.md`
- [ ] 4.3 Add cleanup step to release workflow that deletes the temporary keychain on success and failure
- [ ] 4.4 Add a test step to the release workflow that runs the full test suite before archiving; halt on failure

## 5. Documentation

- [ ] 5.1 Write `README.md` using this exact structure:
  1. Centered `# Prizm` headline
  2. Badge row: CI build status, Swift 6.2, macOS 26+, license
  3. One-liner: "Native macOS client for Vaultwarden and self-hosted Bitwarden, built in Swift."
  4. Tagline: "Your secrets. Your server. Our user interface."
  5. Screenshot placeholder
  6. **Why Prizm** — Mac Gap framing, honest comparison to official Bitwarden client (native vs. Electron)
  7. **Privacy** — no telemetry, no analytics, no cloud; nothing leaves your server
  8. **Security** — 3-bullet inline summary (Argon2id RFC 9106, AES-256-CBC + HMAC-SHA256, macOS Keychain) + link to SECURITY.md
  9. **Features** — user-centric list (what you can do, not how it works)
  10. **Requirements** — macOS 26+, self-hosted Vaultwarden or Bitwarden, tested compatibility
  11. **Install** — (a) unsigned DMG + Gatekeeper bypass with honest explanation of why it is unsigned, (b) build from source one-liner, (c) link to DEVELOPMENT.md
  12. **Roadmap** — Now/Next/Later table
  13. **Known Limitations** — direct honest list
  14. **Contributing** — link to DEVELOPMENT.md, mention openspec workflow
  15. **Mission & Principles** — adapted from approved draft (closing statement)
- [ ] 5.2 Write `DEVELOPMENT.md` — prerequisites (Xcode version, macOS 26+), cloning, LocalConfig.xcconfig setup (with note that build fails without it), build command, test command, architecture overview (three-layer), openspec workflow, contributing notes, GitHub secrets documentation for release signing (`CERT_P12`, `CERT_PASSWORD`, `NOTARYTOOL_KEY`, `NOTARYTOOL_KEY_ID`, `NOTARYTOOL_ISSUER_ID`) with description and source for each
- [ ] 5.3 Write `SECURITY.md` — threat model, encryption algorithm and key derivation with inline spec references (Argon2id per RFC 9106, EncString per Bitwarden Security Whitepaper), key storage (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), what is and is not protected (explicit out-of-scope threats), vulnerability reporting via GitHub Security Advisories (private disclosure)

## 6. Verification

- [ ] 6.1 Grep for any remaining `Macwarden` or `macwarden` references across all files — must be zero
- [ ] 6.2 Confirm app icon renders correctly at all sizes on a real macOS build
- [ ] 6.3 Confirm Release build archives cleanly with Hardened Runtime enabled
- [ ] 6.4 Confirm README renders correctly on GitHub (centered headline, table, links)
- [ ] 6.5 Confirm SECURITY.md satisfies CONSTITUTION §VII checklist (security goal, algorithm + spec ref, deviations, intentional omissions)
