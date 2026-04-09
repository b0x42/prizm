## Context

Prizm distributes an unsigned DMG via GitHub Releases. Users who download through a browser must manually run `xattr -dr com.apple.quarantine` before macOS allows the app to launch. Homebrew casks automate this entire flow and are the de facto install method for macOS power users.

The release workflow already produces versioned DMGs (`Prizm-v{version}.dmg`) attached to GitHub Releases. No pipeline changes are needed.

## Goals / Non-Goals

**Goals:**
- Provide a `brew install --cask prizm` install path via a custom tap
- Keep the cask formula in a separate `homebrew-prizm` repository so it can be versioned independently of the app
- Document the Homebrew install method in the README

**Non-Goals:**
- Submitting to the official `homebrew-cask` tap (requires popularity thresholds and code signing)
- Automating cask version bumps in CI (manual updates are fine for now)
- Changing the release workflow or DMG naming

## Decisions

1. **Separate tap repository (`b0x42/homebrew-prizm`)** over embedding casks in the main repo.
   - Homebrew convention: `brew tap <user>/<name>` maps to `github.com/<user>/homebrew-<name>`. A dedicated repo follows this convention cleanly.
   - Keeps the main repo focused on app source code.
   - Alternative: self-tap via `Casks/` in this repo — works but is non-standard and clutters the project root.

2. **Versioned DMG URL with `#{version}` interpolation** over a fixed `Prizm.dmg` filename.
   - The release workflow already produces `Prizm-v{version}.dmg`. The cask interpolates this naturally.
   - Users who download manually retain version info in the filename.

3. **`depends_on macos: ">= :tahoe"`** to enforce the macOS 26 requirement at install time.
   - Prevents confusing launch failures on older macOS versions.

## Risks / Trade-offs

- **Manual cask updates**: Each release requires manually updating `version` and `sha256` in the cask formula. → Acceptable for current release cadence; CI automation can be added later.
- **Unsigned app warning**: Even via Homebrew, macOS may still show a warning on first launch since the app is unsigned. → Homebrew handles quarantine removal, but Gatekeeper may still intervene. Users can right-click → Open to bypass.
- **Tap discoverability**: Custom taps require users to know the tap name. → Document prominently in README.
