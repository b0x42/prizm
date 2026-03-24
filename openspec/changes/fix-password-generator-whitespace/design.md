## Context

`PasswordGenerator.symbolChars` is defined as `Array("!@#$%^&*()_+-=[]{}|;':\",.< >?/")`. The space between `<` and `>` is a typo — the intended set (per the `password-generator` spec) is `!@#$%^&*()_+-=[]{}|;':",.<>?/` with no whitespace. This is a one-line constant fix.

## Goals / Non-Goals

**Goals:**
- Remove the space character from `symbolChars` so generated passwords never contain whitespace

**Non-Goals:**
- Changing the symbol set composition beyond removing the space
- Adding a "custom symbols" configuration option
- Regenerating or invalidating previously generated passwords

## Decisions

- **Fix the constant, not the generation logic.** The bug is in the data (`symbolChars`), not the algorithm. Alternatives: adding a post-generation whitespace strip, or filtering the pool — both add unnecessary complexity for a data typo.

## Risks / Trade-offs

- [Low] Users who relied on spaces in generated passwords will see different output. → Acceptable; spaces in passwords are a defect, not a feature.
