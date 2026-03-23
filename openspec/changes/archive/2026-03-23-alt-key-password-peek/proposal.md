## Why

When browsing the vault, checking a password requires clicking the reveal toggle, reading the value, then clicking again to hide it. For quick glances this is too many steps. Holding the Option (⌥) key while an item is selected should temporarily reveal the password, hiding it the instant the key is released — a fast, zero-click peek.

## What Changes

- Add a global Option-key monitor that publishes a boolean "is Option held" state
- `MaskedFieldView` temporarily reveals its value while the Option key is held, without changing the persisted reveal/hide toggle state
- Releasing the key immediately re-masks the field
- The existing click-to-toggle reveal behaviour remains unchanged

## Capabilities

### New Capabilities

- `alt-key-password-peek`: Temporarily reveal masked fields by holding the Option key while an item is selected

### Modified Capabilities

- `vault-browser-ui`: Add requirement for Option-key peek on masked secret fields

## Impact

- `Presentation/Components/MaskedFieldView.swift` — read Option-key state and conditionally show plaintext (also contains `MaskedFieldState`)
- A new `OptionKeyMonitor` utility using `NSEvent.addLocalMonitorForEvents`
- No Domain or Data layer changes
- No new dependencies
