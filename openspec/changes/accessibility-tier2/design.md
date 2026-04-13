## Context

The accessibility-baseline change (PR #37) added VoiceOver labels, hints, values, heading traits, and a VPAT conformance statement. Three criteria remain "Partially Supports": colour contrast (1.4.3, 1.4.11), error suggestions (3.3.3), and focus management (2.4.3 — untested). The app also ignores the macOS Reduce Motion and Increase Contrast accessibility preferences.

Current custom opacity usage (6 instances across 6 files):
- `Color.yellow.opacity(0.15)` — sync error banner background
- `Color.primary.opacity(0.08)` — card border stroke
- `Color.secondary.opacity(0.1)` — trash banner background
- `Color.red.opacity(0.1)` — error banner backgrounds (ItemEditView, AttachmentConfirmSheet)
- `Color.accentColor.opacity(0.2)` — folder drop target highlight

Current animation usage (13 instances across 7 files):
- `withAnimation(.easeInOut(duration: 0.15))` — hover state transitions (FieldRowView, AttachmentRowView)
- `withAnimation(.easeInOut(duration: 0.1))` — copy feedback (FieldRowView)
- `withAnimation(.easeInOut(duration: 0.2))` — match type toggle (LoginEditForm)
- `.animation(.easeInOut(duration: 0.15), value:)` — drag border (AttachmentsSectionView)
- `.animation(.easeInOut, value:)` — sync progress message (SyncProgressView)
- `.transition(.opacity)` — hover actions, error messages, biometric button (FieldRowView, AttachmentRowView, AttachmentsSectionView, LoginView, UnlockView, LoginEditForm) — these are driven by enclosing `withAnimation` and become instant when animation is suppressed

## Goals / Non-Goals

**Goals:**
- All custom opacity values meet WCAG contrast thresholds in light and dark mode
- Increase Contrast preference raises opacity values for better visibility
- Error messages include actionable suggestions where possible
- Focus returns to a logical element after sheet/alert dismiss and item delete
- Animations are suppressed when Reduce Motion is enabled
- ACCESSIBILITY.md updated to reflect improved conformance

**Non-Goals:**
- Keyboard alternative for drag-and-drop (separate change — requires new UI for "Move to Folder")
- Switch Control testing
- Full VoiceOver end-to-end test automation

## Decisions

### Decision 1: Contrast — raise opacity values, don't replace colours

The custom opacity values are used for subtle background tints on banners and borders. Rather than replacing them with opaque named colours (which would lose the adaptive light/dark behaviour), raise the opacity values to meet contrast thresholds. The background tints don't contain text directly — text sits on top with `.primary` or `.red` foreground — so the 3:1 non-text contrast ratio applies to the tinted background against the surrounding card/window background.

Measured values (approximate, using macOS Digital Color Meter):
- `Color.yellow.opacity(0.15)` on white → ~#FFF9D9 → contrast with white window: ~1.05:1 (fails 3:1). Raise to `0.35`.
- `Color.primary.opacity(0.08)` border → barely visible. Raise default to `0.12`; Increase Contrast to `0.2`.
- `Color.secondary.opacity(0.1)` → ~#F5F5F5 on white → ~1.07:1 (fails). Raise to `0.25`.
- `Color.red.opacity(0.1)` → ~#FFE5E5 → ~1.06:1 (fails). Raise to `0.25`.
- `Color.accentColor.opacity(0.2)` → transient drop target, not persistent UI. Acceptable as-is but raise to `0.3` for Increase Contrast.

### Decision 2: Increase Contrast via `@Environment(\.accessibilityContrast)`

SwiftUI exposes `\.accessibilityContrast` which returns `.increased` when the user enables "Increase contrast" in System Settings → Accessibility → Display. Use a small helper that returns a higher opacity when increased contrast is active. This avoids scattering `@Environment` reads across every view — a single `ContrastAwareOpacity` utility handles it.

### Decision 3: Reduce Motion via `@Environment(\.accessibilityReduceMotion)`

When `accessibilityReduceMotion` is true, replace `withAnimation` calls with immediate state changes (no animation). For `.transition(.opacity)`, keep the transition but remove the animation timing. A small helper `optionalAnimation(_:body:)` wraps the check.

### Decision 4: Error suggestions — append to existing `errorDescription`

Rather than adding a separate `recoverySuggestion` property (which SwiftUI alerts don't display by default), append the suggestion directly to the `errorDescription` string. This keeps the fix minimal and ensures the suggestion is always visible.

### Decision 5: Focus management — use `@FocusState` bindings

After sheet dismiss: SwiftUI returns focus to the triggering element by default. Verify this works. After item delete: explicitly set focus to the item list or the next item via `@FocusState`. After alert dismiss: SwiftUI handles this natively.

## Risks / Trade-offs

- **Opacity values are approximate**: Exact contrast ratios depend on the system appearance, display calibration, and whether the user has custom accent colours. The raised values are conservative estimates. Mitigation: test in both light and dark mode with Digital Color Meter.
- **Reduce Motion removes visual feedback**: Hover state changes and copy confirmation will be instant rather than animated. This is the correct behaviour per WCAG 2.3.3 but may feel abrupt. Mitigation: the state change still occurs, only the animation is removed.
- **Error message length increases**: Adding suggestions makes error strings longer. Mitigation: suggestions are short (one sentence) and only added where actionable.
