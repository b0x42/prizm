## ADDED Requirements

### Requirement: User can generate a random password with configurable options
The system SHALL provide a password generator that produces cryptographically random character-based passwords. The generator SHALL support the following configuration options: length (integer, 5–128 inclusive, default 16), uppercase letters toggle (A–Z, default on), lowercase letters toggle (a–z, default on), digits toggle (0–9, default on), symbols toggle (`!@#$%^&*()_+-=[]{}|;':",.<>?/`, default on), and avoid-ambiguous-characters toggle (excludes `0`, `O`, `I`, `l`, `1`, `|` from all enabled sets, default off). The generated password SHALL contain at least one character from each enabled character set. The system SHALL prevent the user from disabling all character sets simultaneously — the last remaining enabled set's toggle SHALL be locked and non-interactive.

#### Scenario: Default configuration produces a 16-character password
- **WHEN** the generator opens with default settings
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

---

### Requirement: User can generate a passphrase with configurable options
The system SHALL provide a passphrase generator that produces word-based passphrases drawn from the EFF Large Wordlist (7776 words). The generator SHALL support the following configuration options: word count (integer, 3–10 inclusive, default 3), word separator (string, default `"-"`, user-editable), capitalize-each-word toggle (default off), include-number toggle (appends a single random digit 0–9 to one randomly chosen word, default off).

#### Scenario: Default passphrase has 3 words separated by hyphens
- **WHEN** the generator opens in passphrase mode with default settings
- **THEN** it SHALL produce a passphrase of 3 words joined by `"-"`

#### Scenario: Word count change produces the correct number of words
- **WHEN** the user sets word count to 5
- **THEN** the generated passphrase SHALL contain exactly 5 words

#### Scenario: Custom separator is used between words
- **WHEN** the user sets the separator to `"."`
- **THEN** the generated passphrase SHALL use `"."` as the delimiter between every word

#### Scenario: Capitalize toggle uppercases the first letter of each word
- **WHEN** the capitalize toggle is enabled
- **THEN** each word in the passphrase SHALL begin with an uppercase letter

#### Scenario: Include-number toggle appends a digit to one word
- **WHEN** the include-number toggle is enabled
- **THEN** exactly one word in the passphrase SHALL have a single random digit (0–9) appended to it

#### Scenario: Words are drawn from the EFF Large Wordlist
- **WHEN** any passphrase is generated
- **THEN** every word SHALL be a member of the EFF Large Wordlist

---

### Requirement: Generated value preview updates live on every option change
The system SHALL display the currently generated value in a prominent preview area. The preview SHALL update immediately whenever any configuration option changes or the user explicitly requests a new value. The preview SHALL use a monospaced font to aid readability of passwords.

#### Scenario: Preview updates on toggle change
- **WHEN** the user changes any configuration toggle or control
- **THEN** the preview SHALL immediately display a newly generated value reflecting the updated settings

#### Scenario: Refresh button produces a new value with the same settings
- **WHEN** the user clicks the refresh/regenerate button
- **THEN** the preview SHALL show a new value generated with the current settings unchanged

#### Scenario: Mode switch updates the preview
- **WHEN** the user switches between Password and Passphrase modes
- **THEN** the preview SHALL immediately show a value in the new mode

---

### Requirement: User can copy or apply the generated value
The system SHALL provide two primary actions on the generated value: Copy and Use. Copy SHALL write the generated value to the system clipboard and follow the 30-second auto-clear rule (per `vault-browser-ui` clipboard requirement). Use SHALL write the generated value into the password field that triggered the generator and dismiss the popover.

#### Scenario: Copy writes to clipboard and auto-clears after 30 seconds
- **WHEN** the user clicks Copy
- **THEN** the generated value SHALL be placed on the system clipboard and SHALL be auto-cleared after 30 seconds

#### Scenario: Use writes the value to the triggering field
- **WHEN** the user clicks Use
- **THEN** the generated value SHALL be written into the password (or private key) field and the popover SHALL dismiss

#### Scenario: Use replaces any existing field value
- **WHEN** the password field already contains a value and the user clicks Use
- **THEN** the field value SHALL be replaced with the generated value

---

### Requirement: Generator settings are persisted between sessions
The system SHALL persist the user's last-used generator configuration (mode, all option values) to `UserDefaults`. On next open, the generator SHALL restore the previously used configuration. The persisted settings SHALL be classified as UI preferences (not vault data) and SHALL NOT be stored in the Keychain.

#### Scenario: Settings are restored on next open
- **WHEN** the user closes the generator popover and reopens it
- **THEN** all configuration controls SHALL reflect the values used in the previous session

#### Scenario: Default settings apply on first launch
- **WHEN** the generator is opened for the first time with no persisted settings
- **THEN** all controls SHALL show their default values

---

### Requirement: Generator is accessible from the password field in the Login edit form
The system SHALL display a generator trigger button adjacent to the password field in the Login item edit sheet. Clicking the button SHALL open the password generator popover anchored to that button. The trigger button SHALL be visible at all times (not hover-only) within the edit form.

#### Scenario: Generator button visible on Login edit password field
- **WHEN** the Login edit sheet is open
- **THEN** a generator trigger button SHALL be visible alongside the password field

#### Scenario: Clicking generator button opens the popover
- **WHEN** the user clicks the generator trigger button on the password field
- **THEN** the password generator popover SHALL open anchored to the button

---

### Requirement: Generator is accessible from the private key field in the SSH Key edit form
The system SHALL display a generator trigger button adjacent to the private key field in the SSH Key item edit sheet. Clicking the button SHALL open the password generator popover anchored to that button.

#### Scenario: Generator button visible on SSH Key edit private key field
- **WHEN** the SSH Key edit sheet is open
- **THEN** a generator trigger button SHALL be visible alongside the private key field

#### Scenario: Clicking generator button opens the popover
- **WHEN** the user clicks the generator trigger button on the private key field
- **THEN** the password generator popover SHALL open anchored to the button
