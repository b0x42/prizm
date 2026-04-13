## 1. Contrast-Aware Opacity Helper

- [x] 1.1 Create `ContrastAwareOpacity` utility in `Prizm/Presentation/` that reads `@Environment(\.accessibilityContrast)` and returns a higher opacity when `.increased`
- [x] 1.2 Define default and increased opacity constants for each usage: banner background, card border, trash banner, error banner, drop target

## 2. Colour Contrast Fixes

- [x] 2.1 Raise `Color.yellow.opacity(0.15)` to `0.35` (increased: `0.5`) on sync error banner in `VaultBrowserView`
- [x] 2.2 Raise `Color.primary.opacity(0.08)` to `0.12` (increased: `0.2`) on card border in `CardBackground`
- [x] 2.3 Raise `Color.secondary.opacity(0.1)` to `0.2` (increased: `0.3`) on trash banner in `ItemDetailView`
- [x] 2.4 Raise `Color.red.opacity(0.1)` to `0.2` (increased: `0.3`) on error banner in `ItemEditView`
- [x] 2.5 Raise `Color.red.opacity(0.1)` to `0.2` (increased: `0.3`) on error banner in `AttachmentConfirmSheet`
- [x] 2.6 Raise `Color.accentColor.opacity(0.2)` to `0.25` (increased: `0.4`) on drop target in `SidebarView`

## 3. Reduce Motion Support

- [x] 3.1 Create `optionalAnimation` helper that checks `accessibilityReduceMotion` and applies `withAnimation` only when motion is allowed
- [x] 3.2 Wrap hover `withAnimation` in `FieldRowView` (2 instances) with reduce motion check
- [x] 3.3 Wrap copy feedback `withAnimation` in `FieldRowView` (2 instances) with reduce motion check
- [x] 3.4 Wrap hover `withAnimation` in `AttachmentRowView` with reduce motion check
- [x] 3.5 Wrap match type toggle `withAnimation` in `LoginEditForm` with reduce motion check
- [x] 3.6 Wrap drag border `.animation` in `AttachmentsSectionView` with reduce motion check
- [x] 3.7 Wrap `.animation(.easeInOut, value: message)` in `SyncProgressView` with reduce motion check

## 4. Error Suggestions

- [x] 4.1 Update `AuthError.invalidURL` to append "Make sure to include https://"
- [x] 4.2 Update `AuthError.invalidCredentials` to append "Check your email and master password."
- [x] 4.3 Update `AuthError.serverUnreachable` to append "Verify the URL and check your connection."
- [x] 4.4 Update `AuthError.networkUnavailable` to append "Check your network connection."
- [x] 4.5 Update `SyncError.unauthorized` to append "Try signing out and signing in again."
- [x] 4.6 Update `SyncError.networkUnavailable` to append "Check your network connection."

## 5. Focus Management

- [x] 5.1 Verify focus returns to detail pane after edit sheet dismiss — fix with `@FocusState` if needed
- [x] 5.2 After item soft delete, set `itemSelection` to the next item in the list (or nil if empty)
- [x] 5.3 Verify focus returns after alert dismiss — SwiftUI handles this natively, document if no fix needed

## 6. Documentation

- [x] 6.1 Update `ACCESSIBILITY.md` — change 1.4.3, 1.4.11 to "Supports", 3.3.3 to "Supports", add Reduce Motion and Increase Contrast notes
- [x] 6.2 Update known gaps section — remove contrast and error suggestion gaps

## 7. Tests

- [x] 7.1 Unit test `ContrastAwareOpacity` returns higher values when contrast is `.increased`
- [x] 7.2 Unit test `optionalAnimation` suppresses animation when reduce motion is true
- [x] 7.3 Update existing `AuthError` / `SyncError` tests if they assert on `errorDescription` strings
