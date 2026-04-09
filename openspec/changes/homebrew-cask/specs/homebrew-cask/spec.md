## ADDED Requirements

### Requirement: Homebrew tap repository exists with a valid cask formula
The `b0x42/homebrew-prizm` repository SHALL contain a cask formula at `Casks/prizm.rb` that installs Prizm from the GitHub Releases DMG.

#### Scenario: User taps and installs Prizm
- **WHEN** a user runs `brew tap b0x42/prizm && brew install --cask prizm`
- **THEN** Homebrew downloads the versioned DMG, extracts `Prizm.app`, and places it in `/Applications`

#### Scenario: Cask formula references correct DMG URL
- **WHEN** the cask formula is evaluated
- **THEN** the `url` field resolves to `https://github.com/b0x42/prizm/releases/download/v{version}/Prizm-v{version}.dmg`

### Requirement: Cask formula includes correct metadata
The cask formula SHALL include `name`, `desc`, `homepage`, and `sha256` fields matching the Prizm project.

#### Scenario: Brew info displays correct metadata
- **WHEN** a user runs `brew info --cask prizm`
- **THEN** the output shows the app name as "Prizm", description as "Native macOS client for Vaultwarden and self-hosted Bitwarden", and homepage as the GitHub repository URL

### Requirement: Cask enforces minimum macOS version
The cask formula SHALL declare `depends_on macos: ">= :tahoe"` to prevent installation on unsupported macOS versions.

#### Scenario: Install attempted on macOS 15
- **WHEN** a user runs `brew install --cask prizm` on macOS 15 (Sequoia)
- **THEN** Homebrew refuses to install with a message indicating the macOS version requirement is not met

### Requirement: Cask declares the app artifact
The cask formula SHALL declare `app "Prizm.app"` so Homebrew moves the app to `/Applications` and manages uninstall.

#### Scenario: User uninstalls Prizm via Homebrew
- **WHEN** a user runs `brew uninstall --cask prizm`
- **THEN** Homebrew removes `Prizm.app` from `/Applications`
