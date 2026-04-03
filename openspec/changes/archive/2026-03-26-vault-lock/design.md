## Context

The Data layer already has everything needed to lock the vault:

- `AuthRepository.lockVault()` — zeros in-memory crypto key material and posts `.vaultDidLock` notification
- `VaultRepository.clearVault()` — clears the in-memory item cache
- `.vaultDidLock` notification — `ItemEditViewModel` already observes this to dismiss open edit sheets
- `UnlockView` / `UnlockViewModel` — the unlock screen already exists and works
- `AuthRepository.storedAccount()` — returns the stored account from Keychain (Keychain is not cleared on lock, only on sign-out)

What is missing is a `lockVault()` entry point on `RootViewModel` and the system observers that trigger it.

## Goals / Non-Goals

**Goals:**
- Manual lock via ⌘L menu command
- Automatic lock on Mac sleep
- Automatic lock on screensaver start
- Lock transitions to the existing unlock screen (no new UI)
- Lock clears both key material and vault item cache

**Non-Goals:**
- Idle timeout (requires a settings UI — deferred)
- Lock on app backgrounding / window hide
- Biometric unlock (separate feature)
- Any change to the unlock screen itself

## Decisions

### Decision 1: `lockVault()` lives on `RootViewModel`

**Chosen:** `RootViewModel.lockVault()` coordinates the lock sequence and drives the screen transition.

**Rationale:** `RootViewModel` is the sole owner of `screen` state. It already owns `signOut()` which follows a similar pattern (clear state → transition screen). Keeping lock alongside sign-out keeps the state machine in one place.

**Alternative considered:** A dedicated `LockUseCase` in the Domain layer. Rejected — lock is not a domain operation (it has no server interaction), it is a local session lifecycle event. The Domain layer would only add indirection with no benefit.

**Constitution §II note:** Having `RootViewModel` call `authRepository.lockVault()` and `vaultStore.clearVault()` directly is a known deviation from §II ("all data access flows through Domain use cases"). This is an acknowledged existing pattern — `signOut()` already does the same. A `LockUseCase` was explicitly considered and rejected above.

### Decision 2: Call both `authRepository.lockVault()` and `vaultStore.clearVault()`

**Chosen:** `RootViewModel.lockVault()` calls both explicitly.

**Rationale:** `authRepository.lockVault()` currently only zeros crypto keys and posts the notification — it does not clear the vault item cache. `vaultStore.clearVault()` must be called separately. Doing both in `RootViewModel` is explicit and auditable; it mirrors what `signOut()` already does.

**Alternative considered:** Have `AuthRepositoryImpl.lockVault()` internally call `clearVault()` by holding a reference to `VaultRepository`. Rejected — would create a dependency from `AuthRepositoryImpl` into `VaultRepositoryImpl`, coupling two repositories that are currently independent.

### Decision 3: Observers owned by `RootViewModel`, not `PrizmApp`

**Chosen:** Sleep and screensaver observers set up in `RootViewModel.subscribeToFlowStates()`.

**Rationale:** `RootViewModel` already owns all session lifecycle logic (login, unlock, sign-out). The observers need to call `lockVault()` which lives on `RootViewModel`. Keeping them co-located avoids passing a callback through `PrizmApp`.

### Decision 4: Guard with `screen == .vault` check

**Chosen:** `lockVault()` proceeds if `screen == .vault || screen == .syncing`, and is a no-op otherwise.

**Rationale:** Sleep and screensaver notifications fire regardless of app state. The guard must cover both `.vault` (fully loaded) and `.syncing` (unlocked but sync still running) — in both states vault keys are in memory and must be zeroed. Any other screen (`.login`, `.unlock`, `.loading`, `.totpPrompt`) means no keys are in memory; locking would be a no-op or incorrect. The underlying `crypto.lockVault()` is safe to call when already locked, but the screen transition and `unlockVM` creation must be guarded.

## Risks / Trade-offs

- **`RootViewModelDependencies` protocol added for testability** — `RootViewModel` originally took `AppContainer` directly. During implementation, a `RootViewModelDependencies` protocol was extracted so tests can inject mocks without a real `AppContainer`. `AppContainer` conforms via a thin extension. No functional change; the protocol is purely a testing seam.
- **Sleep fires before the vault is reached** — if the user triggers sleep from the login screen, the guard handles it silently. No risk.
- **Race between sleep and sign-out** — if the user signs out while sleep fires concurrently, both paths call `lockVault()`; the guard on `screen == .vault` means only one will proceed. Safe.
- **`vaultStore` exposed on `AppContainer`** — `AppContainer` already exposes `vaultStore: VaultRepositoryImpl` directly. This is used here; no new coupling introduced.
- **Screensaver notification reliability** — `com.apple.screensaver.didstart` is a private distributed notification. It has been stable across macOS versions and is used by 1Password and other password managers for the same purpose. No public API alternative exists.
- **Screen lock (⌃⌘Q) is a separate event** — locking the screen does not trigger the screensaver or sleep notifications. A third observer on `com.apple.screenIsLocked` (distributed notification) was added to cover this case. Same stability profile as the screensaver notification.
