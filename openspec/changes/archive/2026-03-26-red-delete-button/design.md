## Context

Delete buttons in `VaultBrowserView`, `ItemListView`, and `TrashView` use SwiftUI's `Button(role: .destructive)` which applies system-default destructive styling. On macOS, this does not always render the button text in red (e.g. toolbar buttons). The change adds explicit `.foregroundStyle(.red)` to ensure consistent red text.

## Goals / Non-Goals

**Goals:**
- All delete-action button labels render with red text across toolbar, context menu, and alert surfaces.

**Non-Goals:**
- Changing button shapes, icons, or layout.
- Modifying alert button styling (alerts already use `.destructive` role which the system renders correctly).

## Decisions

- Apply `.foregroundStyle(.red)` directly to toolbar `Button` labels in `VaultBrowserView`. Context menu buttons with `role: .destructive` already render red text on macOS, so no change is needed there. Toolbar buttons are the primary target since `role: .destructive` alone does not guarantee red text in toolbar placement.
- Keep `role: .destructive` alongside the color override so the semantic role is preserved for accessibility and system behavior (e.g. alert ordering).

## Risks / Trade-offs

- [Minimal] Hardcoded `.red` may not adapt to future system accent changes → Acceptable for a destructive action; `.red` is the universal convention.

## HIG Notes (for future reference)

Apple HIG and macOS toolbar conventions suggest delete is not a primary toolbar action:

- Toolbars should contain the most frequently used commands; delete is typically secondary/contextual.
- Apple's own apps (Mail, Finder, Notes) use a trash **icon** in the toolbar (not a text label), grouped with other actions, and rely on context menus + ⌫ for the primary delete flow.
- "Delete Permanently" never appears in Apple's toolbars — it's only in context menus or the Edit menu.
- The hypothetical email app in Mario Guzman's [Mac Toolbar Guidelines](https://marioaguzman.github.io/design/toolbarguidelines/) ranks delete as third-priority, behind compose and reply actions.

Current Prizm approach (text "Delete" / "Delete Permanently" buttons in the toolbar with confirmation alerts) trades strict HIG alignment for discoverability — acceptable for a power-user app. Future consideration: replace text labels with a trash icon button, or move permanent delete to context menu only.
