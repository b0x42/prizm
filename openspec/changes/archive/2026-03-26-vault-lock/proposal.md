## Why

A password manager must be lockable. Currently the vault stays open indefinitely — there is no manual lock command and the vault is not locked when the Mac sleeps or the screensaver starts. The lock infrastructure already exists in the Data layer but is never triggered except on sign-out.

## What Changes

- Add `lockVault()` to `RootViewModel` — zeros in-memory keys, clears vault item cache, transitions to the existing unlock screen
- Add **Lock Vault** menu command with ⌘L shortcut (disabled when not on the vault screen)
- Lock automatically when the Mac goes to sleep (`NSWorkspace.willSleepNotification`)
- Lock automatically when the screensaver starts (`com.apple.screensaver.didstart` via `DistributedNotificationCenter`)
- Guard against double-lock: `lockVault()` is a no-op if the vault is not currently unlocked

## Capabilities

### New Capabilities

- `vault-lock`: Lock the vault manually or automatically, clearing all in-memory key material and the item cache, and returning to the unlock screen

### Modified Capabilities

*(none — the unlock screen and underlying lock primitives are unchanged; this change only wires them up)*

## Impact

- `MacwardenApp.swift` — new ⌘L `CommandGroup` entry
- `RootViewModel` — new `lockVault()` method, sleep and screensaver observers added to `subscribeToFlowStates()`
- No new dependencies; no API changes; no Keychain changes
