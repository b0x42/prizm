## Context

The edit flow has no way to generate passwords. Users who want strong credentials must leave the app, generate elsewhere, copy, and return. This creates friction for the "register for a new service" workflow and is a prerequisite for a usable "create new item" feature.

The existing `EditFieldRow` / `MaskedFieldView` infrastructure handles all sensitive field rendering. `LoginEditForm` and `SSHKeyEditForm` bind directly to `DraftLoginContent` and `DraftSSHKeyContent` respectively via `@Binding`. The Data layer's `BitwardenCryptoService` handles encryption on save — the generator has no interaction with that path.

## Goals / Non-Goals

**Goals:**
- Cryptographically secure random generation (random and passphrase modes)
- Fully configurable via popover UI; live preview on every change
- Minimal invasiveness on existing edit form code
- Settings remembered across sessions (UI pref, not vault data)
- Testable pure Domain utility with no UI dependencies

**Non-Goals:**
- Password strength meter or entropy display
- Autofill trigger (separate feature)
- Password history / audit trail
- Bitwarden server sync of generator settings

## Decisions

### 1. CSPRNG: `SecRandomCopyBytes` over `SystemRandomNumberGenerator`

`SecRandomCopyBytes` (Security.framework) is explicitly documented as cryptographically secure and is the standard Apple API for this purpose. `SystemRandomNumberGenerator` delegates to the OS CSPRNG in practice but the Swift stdlib API does not formally guarantee cryptographic quality. For a credential vault, the stronger explicit guarantee is preferred. This keeps `PasswordGenerator` in the Domain layer — Security.framework is already imported there via `KeychainService`.

**Rejected alternative:** `arc4random_uniform` — deprecated on Apple platforms; `SystemRandomNumberGenerator` — adequate in practice but weaker documentation guarantee.

### 2. Word list: bundled EFF Large Wordlist (7776 words)

The EFF Large Wordlist is the industry standard for diceware-style passphrases and is what Bitwarden's own web vault uses. Bundled as `eff-large-wordlist.txt` (~60 KB) in the app bundle, loaded once and cached in the `PasswordGenerator`. This gives users a familiar vocabulary and maximises entropy per word (log₂(7776) ≈ 12.9 bits/word).

**Rejected alternative:** Hardcoded Swift array — bloats the binary with string data better kept as a resource; harder to audit or update.

### 3. Character inclusion guarantee algorithm

To guarantee at least one character from every enabled set:
1. Pick one random character from each enabled set.
2. Fill remaining slots with random characters drawn from the full union of enabled sets.
3. Shuffle the complete array using Fisher-Yates (via `SecRandomCopyBytes`).

This distributes all character types uniformly rather than front-loading the required characters, which would produce a biased distribution.

**Rejected alternative:** Rejection sampling (keep generating until constraints are met) — non-deterministic runtime; can loop on degenerate configs.

### 4. Popover over sheet

The generator opens as a `.popover` anchored to the trigger button. Rationale: a popover floats above the edit form without obscuring it, the user retains context (they can see the field they're filling), and it is the standard macOS pattern for transient utility panels (e.g., font picker, colour picker).

**Rejected alternative:** `.sheet` — blocks the edit form entirely; overkill for a single-purpose utility panel.

### 5. Binding-based "Use" action

`PasswordGeneratorView` receives a `Binding<String?>` for the target field. On "Use", it writes through the binding and triggers popover dismissal via `@Environment(\.dismiss)`. No callbacks, no delegate protocol, no ViewModel-to-ViewModel communication.

**Rejected alternative:** Callback closure `onUse: (String) -> Void` — achieves the same result but introduces a closure capture where a binding already models the relationship.

### 6. Generator settings in `UserDefaults` directly

Generator configuration (`PasswordGeneratorConfig`) is serialised to `UserDefaults` as individual keys (not a single encoded struct). This is consistent with how the project handles other UI preferences and avoids adding a repository protocol for trivial persisted UI state. Settings are explicitly scoped as UI preferences (not vault data) and are NOT stored in the Keychain.

### 7. `PasswordGeneratorViewModel` as `@MainActor ObservableObject`

Consistent with `ItemEditViewModel`, `LoginViewModel`, etc. The generator is UI-only and always runs on the main actor. No async work required — generation is synchronous and cheap even at maximum length (128 chars, 7776-word list).

### 8. `EditFieldRow` extension point

Add an optional `generatorBinding: Binding<String?>?` parameter to `EditFieldRow`. When non-nil, a wand SF Symbol button is rendered adjacent to the field. All existing call sites pass `nil` implicitly and are unaffected. Only the two target fields (`LoginEditForm` password, `SSHKeyEditForm` private key) pass a binding.

## Risks / Trade-offs

**Passphrase entropy is lower than random passwords**
3 words from 7776 → ~38.9 bits; 4 words → ~51.8 bits; a 16-char random password with all sets → ~100 bits. The passphrase mode UI should default to at least 3 words. Consider displaying word count minimum guidance. → *Accepted trade-off*: matches Bitwarden's defaults; users wanting high-entropy can increase word count.

**EFF word list loading latency**
First-time load parses ~60 KB of text. On modern hardware this is sub-millisecond, but the load should be lazy (on first generator open, not at app startup). → *Mitigation*: Load and cache in `PasswordGenerator.init()` only when the popover first opens; use `lazy var` or a static once-token.

**Ambiguous-character set interaction with limited character pool**
If avoid-ambiguous is on and only digits are enabled, the pool reduces to `{2,3,4,5,6,7,8,9}` (8 chars). At length > 8 characters, repetition is inevitable. This is a valid but edge case the user has deliberately constructed. → *Accepted*: no special handling needed; repetition in this scenario is expected.

## Open Questions

- **Symbols set definition**: Use Bitwarden's exact symbol set (`!@#$%^&*`) or a broader set? Bitwarden's web vault uses `!@#$%^&*` by default with an "all special" option. For v1, using the broader set (`!@#$%^&*()_+-=[]{}|;':",.<>?/`) is proposed — confirm acceptable.
- **Entropy display**: Should the popover show a calculated entropy value (in bits)? Out of scope for v1 per proposal but easy to add later. Deferred.
