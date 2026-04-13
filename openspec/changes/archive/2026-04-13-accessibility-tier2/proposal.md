## Why

The accessibility-baseline change added VoiceOver labels, hints, values, and a conformance statement. Three WCAG 2.1 AA criteria remain at "Partially Supports" in the VPAT: colour contrast (1.4.3, 1.4.11), error suggestions (3.3.3), and focus management is untested (2.4.3). Additionally, the app does not respect the macOS Reduce Motion or Increase Contrast accessibility settings. This change closes those gaps.

## What Changes

- **Colour contrast fixes**: Audit and fix all custom `opacity()` values — `Color.yellow.opacity(0.15)` sync error banner background, `Color.primary.opacity(0.08)` card border, `Color.secondary.opacity(0.1)` trash banner, `Color.red.opacity(0.1)` error banner, `Color.accentColor.opacity(0.2)` drop target — to meet WCAG 3:1 non-text contrast thresholds in both light and dark mode
- **Increase Contrast support**: When `accessibilityIncreaseContrast` is enabled, raise opacity values on backgrounds and borders to improve visibility
- **Error suggestions**: Add corrective hints to error messages — `AuthError.invalidURL` ("Include https://"), `AuthError.serverUnreachable` ("Check the URL and your connection"), `AuthError.invalidCredentials` ("Check your email and master password"), `SyncError.unauthorized` ("Sign out and sign in again")
- **Focus management verification**: Audit and fix focus after sheet dismiss, alert dismiss, and item delete so focus returns to a logical element
- **Reduce Motion support**: Wrap all `withAnimation` and `.animation` calls in `accessibilityReduceMotion` checks — 13 animation instances across 7 files

## Capabilities

### New Capabilities

- `accessibility-contrast`: Colour contrast compliance and Increase Contrast support
- `accessibility-motion`: Reduce Motion support for all animations
- `accessibility-error-suggestions`: Actionable error messages with corrective hints

### Modified Capabilities

- `vault-browser-ui`: Focus management after sheet/alert dismiss and item delete

## Impact

- **Presentation layer**: Opacity values adjusted in 6 files, animations wrapped in 7 files
- **Domain layer**: `errorDescription` strings updated in `AuthError` and `SyncError` (2 enums — `AttachmentError` and `VaultError` already include suggestions)
- **No new dependencies**
- **ACCESSIBILITY.md**: Updated to reflect improved conformance levels
