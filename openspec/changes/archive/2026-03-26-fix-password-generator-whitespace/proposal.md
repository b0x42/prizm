## Why

The password generator's symbol character set contains a literal space character (`",.< >?/"`), causing generated passwords to include spaces when symbols are enabled. Spaces in passwords cause usability issues (hard to see, easy to mis-copy, rejected by some services) and violate user expectations — the spec defines the symbol set as `!@#$%^&*()_+-=[]{}|;':",.<>?/` with no whitespace.

## What Changes

- Remove the space character from the symbol character set in `PasswordGenerator.swift`
- No new features; this is a correctness fix to match the existing spec

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `password-generator`: The symbol character set definition in the spec already excludes spaces; this change fixes the implementation to match. No spec-level requirement change needed — the spec is correct, the code is wrong.

## Impact

- `Prizm/Domain/Utilities/PasswordGenerator.swift` — `symbolChars` constant
- All passwords generated with symbols enabled are affected (default configuration)
- No API, persistence, or dependency changes
