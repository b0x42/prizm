## Context

The app has two issues with destructive actions:

1. **Inconsistent styling** — some destructive buttons use `.foregroundStyle(.red)` and `role: .destructive`, others rely on default styling. Users can't visually distinguish safe from dangerous actions at a glance.
2. **Delete in the wrong place** — the item Delete button sits in the detail toolbar, reachable from the read-only view. Apple Passwords, 1Password, and macOS HIG place delete inside the edit sheet to prevent accidental deletion.

Current state of destructive actions:
- Detail toolbar: Delete (red ✓), Delete Permanently (red ✓) — but Delete shouldn't be here at all
- Sidebar context menus: Delete Folder (`role: .destructive` ✓), Delete Collection (`role: .destructive` ✓)
- Confirmation alerts: Move to Trash (`role: .destructive` ✓), Delete Permanently (`role: .destructive` ✓), Delete Folder (`role: .destructive` ✓), Delete Collection (`role: .destructive` ✓)
- Empty Trash toolbar button: needs verification

## Goals / Non-Goals

**Goals:**
- Move item Delete from detail toolbar into `ItemEditView` at the bottom of the form
- Ensure every destructive button/menu item uses red text or `role: .destructive`
- Keep existing confirmation alert flows unchanged

**Non-Goals:**
- Changing the permanent-delete flow for trashed items (stays in detail toolbar)
- Redesigning the edit sheet layout beyond adding the Delete button
- Adding undo support for delete actions

## Decisions

### 1. Delete button placement in edit sheet

Place a full-width `Button("Delete Item")` with `.foregroundStyle(.red)` at the bottom of the `ItemEditView` form, below all field sections and above the sheet's dismiss area.

**Rationale**: Matches Apple Passwords pattern. Bottom placement means the user must scroll past all fields, reducing accidental taps. The button is only shown for existing items (not during create).

**Alternative considered**: Placing Delete in a toolbar within the edit sheet — rejected because it's still too easy to hit accidentally and doesn't match the reference apps.

### 2. Callback threading

`ItemEditView` receives an `onDelete: ((String) async -> Void)?` closure. When the user confirms deletion, the edit sheet dismisses first, then the delete executes. This avoids the sheet trying to render a deleted item.

**Rationale**: Same pattern used by the existing save flow — dismiss then act.

### 3. Permanent delete stays in detail toolbar

Trashed items are read-only (no edit sheet), so Delete Permanently must remain in the detail toolbar. This is already styled correctly with `.foregroundStyle(.red)`.

## Risks / Trade-offs

- **Discoverability** — users accustomed to the toolbar Delete button may not find it in the edit sheet initially. Mitigated by the fact that this matches the convention in Apple Passwords and 1Password.
- **Extra tap** — deleting now requires opening the edit sheet first. This is intentional friction for a destructive action.
