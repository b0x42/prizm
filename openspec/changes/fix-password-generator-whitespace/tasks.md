## 1. Fix symbol character set

- [x] 1.1 Remove the space character from `symbolChars` in `PasswordGenerator.swift` (change `",.< >?/"` to `",.<>?/"`)
- [x] 1.2 Verify the updated `symbolChars` array matches the spec set exactly: `!@#$%^&*()_+-=[]{}|;':",.<>?/`
- [x] 1.3 Add `testPassword_noWhitespace_withSymbolsEnabled` to `PasswordGeneratorTests.swift` — generate 128-char passwords with symbols enabled across multiple seeds, assert none contain whitespace
