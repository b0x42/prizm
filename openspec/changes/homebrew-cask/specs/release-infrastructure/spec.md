## ADDED Requirements

### Requirement: README documents Homebrew cask installation
The README SHALL include a Homebrew install section under the Install heading that shows the `brew tap` and `brew install --cask` commands.

#### Scenario: User reads install instructions
- **WHEN** a user views the README Install section
- **THEN** they see Homebrew listed as an install method with the exact commands `brew tap b0x42/prizm` and `brew install --cask prizm`
