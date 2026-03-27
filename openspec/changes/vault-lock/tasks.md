## 1. Tests — Vault Lock

- [ ] 1.1 Add unit test: `lockVault()` on `RootViewModel` transitions `screen` to `.unlock`
- [ ] 1.2 Add unit test: `lockVault()` is a no-op when `screen != .vault`
- [ ] 1.3 Add unit test: `lockVault()` calls `authRepository.lockVault()` and `vaultStore.clearVault()`
- [ ] 1.4 Add unit test: `lockVault()` creates a new `unlockVM` from the stored account
- [ ] 1.5 Add unit test: `lockVault()` falls back to `screen = .login` when `storedAccount()` returns nil

## 2. RootViewModel — lockVault()

- [ ] 2.1 Add `lockVault()` method to `RootViewModel` that guards on `screen == .vault || screen == .syncing`, then calls `await container.authRepository.lockVault()` and `container.vaultStore.clearVault()`
- [ ] 2.2 After clearing, retrieve the stored account via `container.authRepository.storedAccount()`, create a new `unlockVM`, and set `screen = .unlock`

## 3. Sleep and Screensaver Observers

- [ ] 3.1 In `subscribeToFlowStates()`, add observer on `NSWorkspace.shared.notificationCenter` for `NSWorkspace.willSleepNotification` → call `lockVault()`
- [ ] 3.2 In `subscribeToFlowStates()`, add observer on `DistributedNotificationCenter.default()` for `com.apple.screensaver.didstart` → call `lockVault()`
- [ ] 3.3 Store both observer tokens and remove them in `deinit`

## 4. Lock Vault Menu Command

- [ ] 4.1 Add a `CommandGroup` entry in `MacwardenApp.commands` with a "Lock Vault" `Button`, `.keyboardShortcut("l", modifiers: .command)`, and `.disabled(!rootVM.isVaultUnlocked)`
- [ ] 4.2 Add `isVaultUnlocked: Bool` computed property to `RootViewModel` (true only when `screen == .vault`)

## 5. UI Test

- [ ] 5.1 Add `testLockVault_withCmdL_transitionsToUnlockScreen` to `VaultBrowserJourneyTests` — unlock vault, press ⌘L, assert unlock screen is shown

## 6. Documentation

- [ ] 6.1 Add ⌘L to the keyboard shortcuts table in README.md
