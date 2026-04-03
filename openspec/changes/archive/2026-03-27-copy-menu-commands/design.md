## Context

`VaultBrowserViewModel.copy(_:)` already handles clipboard write + 30s auto-clear. The Item menu has Edit (⌘E) and Save (⌘S). The selected item is available via `vaultBrowserVM.itemSelection`.

## Goals / Non-Goals

**Goals:**
- Copy Username, Password, TOTP Code, and Website from the menu bar with keyboard shortcuts
- Disabled state when field is unavailable

**Non-Goals:**
- Copy commands for non-Login types (Card number, Identity email — deferred)
- Context menu on list rows (separate feature)

## Decisions

### Decision 1: Commands on RootViewModel, not VaultBrowserViewModel

**Chosen:** `RootViewModel` owns the copy helpers because it already owns menu bar state (`menuBarCanEdit`, `menuBarCanSave`).

**Rationale:** Menu commands live in `PrizmApp.commands` which has access to `rootVM`. Keeping copy logic alongside existing menu state is consistent.

### Decision 2: Login-only for v1

**Chosen:** Copy commands only extract fields from `LoginContent`. Non-Login items disable all four commands.

**Rationale:** Username/Password/TOTP/Website are Login-specific fields. Card number, Identity email etc. can be added later with type-specific menus.
