## Why

Users currently download an unsigned DMG from GitHub Releases and must manually strip the quarantine attribute. A Homebrew cask eliminates this friction — `brew install --cask prizm` handles download, quarantine removal, DMG mounting, and app placement in one command. This is the standard install path macOS power users expect.

## What Changes

- Add a `homebrew-prizm` tap repository structure with a `Casks/prizm.rb` cask formula
- The cask references versioned DMG assets (`Prizm-v{version}.dmg`) from GitHub Releases
- Document the Homebrew install method in the project README

## Capabilities

### New Capabilities
- `homebrew-cask`: Homebrew cask formula and tap repository structure enabling `brew tap b0x42/prizm && brew install --cask prizm`

### Modified Capabilities
- `release-infrastructure`: Release workflow needs no changes — it already produces correctly-named versioned DMGs. README install section needs updating to include Homebrew instructions.

## Impact

- New repository `homebrew-prizm` under `b0x42` GitHub org (or a `Casks/` directory in this repo as a self-tap)
- README.md install section updated with Homebrew instructions
- No code changes to the app itself
- No changes to the existing release workflow
