## MODIFIED Requirements

### Requirement: User can generate a random password with configurable options
The system SHALL provide a password generator that produces cryptographically random character-based passwords. The generator SHALL support the following configuration options: length (integer, 5–128 inclusive, default 16), uppercase letters toggle (A–Z, default on), lowercase letters toggle (a–z, default on), digits toggle (0–9, default on), symbols toggle (`!@#$%^&*()_+-=[]{}|;':",.<>?/`, default on), and avoid-ambiguous-characters toggle (excludes `0`, `O`, `I`, `l`, `1`, `|` from all enabled sets, default off). The generated password SHALL contain at least one character from each enabled character set. The generated password SHALL NOT contain whitespace characters (space, tab, newline). The system SHALL prevent the user from disabling all character sets simultaneously — the last remaining enabled set's toggle SHALL be locked and non-interactive.

#### Scenario: Default configuration produces a 16-character password
- **WHEN** the generator opens in Password mode with default settings
- **THEN** it SHALL produce a 16-character password containing characters from uppercase, lowercase, digits, and symbols sets

#### Scenario: Disabling a character set excludes those characters
- **WHEN** the user disables the symbols toggle
- **THEN** subsequent generated passwords SHALL contain no symbol characters

#### Scenario: At least one character from each enabled set is present
- **WHEN** a password is generated with multiple sets enabled
- **THEN** the result SHALL contain at least one character from each enabled set

#### Scenario: Avoid-ambiguous excludes specified characters
- **WHEN** the avoid-ambiguous toggle is enabled
- **THEN** the generated password SHALL not contain any of the characters `0`, `O`, `I`, `l`, `1`, `|`

#### Scenario: Length slider is clamped to valid range
- **WHEN** the user adjusts the length slider
- **THEN** the length SHALL be constrained to the range 5–128 inclusive

#### Scenario: Last enabled character set cannot be disabled
- **WHEN** only one character set toggle remains enabled
- **THEN** that toggle SHALL be non-interactive and the other disabled toggles SHALL remain operable

#### Scenario: Generated password contains no whitespace
- **WHEN** a password is generated with any combination of enabled character sets
- **THEN** the result SHALL NOT contain any whitespace characters (space, tab, newline, or carriage return)
