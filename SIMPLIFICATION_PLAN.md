# Code Simplification Plan — Macwarden

> Generated: 2026-03-18
> Scope: All `.swift` files under `Macwarden/`
> Goal: Improve clarity, reduce duplication, and enforce consistency — without changing behaviour.

---

## 1. Extract shared `VerticalLabeledContentStyle`

**Priority:** High — exact code duplication across two files.

**Problem:**
`LoginView.swift` and `UnlockView.swift` each define an identical private `VerticalLabeledContentStyle` struct and a matching `LabeledContentStyle` extension. Any future change must be applied in both places.

**Files affected:**
- `Presentation/Login/LoginView.swift`
- `Presentation/Unlock/UnlockView.swift`
- New: `Presentation/Components/VerticalLabeledContentStyle.swift`

**Guidance:**
1. Create `Presentation/Components/VerticalLabeledContentStyle.swift`.
2. Move the struct and extension there with `internal` access (drop `private`).
3. Remove the duplicate definitions from both view files.
4. Add the new file to the Xcode project/target.

---

## 2. Move `sfSymbol(for:)` to `ItemType` extension

**Priority:** High — identical mapping duplicated in two views.

**Problem:**
`SidebarView.sfSymbol(for:)` and `FaviconView.sfSymbol(for:)` contain the same `ItemType → String` switch. If a new item type is added, both must be updated.

**Files affected:**
- `Presentation/Vault/Sidebar/SidebarView.swift`
- `Presentation/Components/FaviconView.swift`
- `Domain/Entities/SidebarSelection.swift` (or a new `ItemType+SFSymbol.swift` in Presentation)

**Guidance:**
1. Add a computed property to `ItemType`:
   ```swift
   extension ItemType {
       var sfSymbol: String {
           switch self {
           case .login:      return "key"
           case .card:       return "creditcard"
           case .identity:   return "person.crop.rectangle"
           case .secureNote: return "note.text"
           case .sshKey:     return "terminal"
           }
       }
   }
   ```
2. If placing UI concerns on a Domain type feels wrong, put the extension in a `Presentation/Components/ItemType+SFSymbol.swift` file instead.
3. Replace both private functions with `type.sfSymbol`.

---

## 3. Wire `LoginViewModel` through `LoginUseCaseImpl`

**Priority:** High — duplicated orchestration logic and an effectively dead use case.

**Problem:**
`LoginViewModel.signIn()` manually calls `auth.validateServerURL`, trims the URL, builds a `ServerEnvironment`, calls `auth.setServerEnvironment`, then `auth.loginWithPassword`, then syncs. `LoginUseCaseImpl.execute()` does the exact same sequence. The use case is injected into `AppContainer` but never used by the view model — the VM bypasses it entirely.

This means:
- The URL-trimming / validation logic is duplicated.
- `LoginUseCaseImpl` is dead code in the running app.
- Any fix to the login orchestration must be applied in two places.

**Files affected:**
- `Presentation/Login/LoginViewModel.swift`
- `Data/UseCases/LoginUseCaseImpl.swift`
- `App/AppContainer.swift`

**Guidance:**

Option A (preferred) — **VM delegates to use case:**
1. Change `LoginViewModel` to depend on `LoginUseCase` instead of `AuthRepository` + `SyncUseCase`.
2. `signIn()` calls `loginUseCase.execute(serverURL:email:masterPassword:)` for the happy path.
3. Keep `auth` dependency only for `loginWithTOTP` (2FA completion), or add a `completeTOTP` method to the use case.
4. Remove the duplicated URL trim/validate/setEnvironment code from the VM.
5. Update `AppContainer.makeLoginViewModel()` to inject the use case.

Option B — **Remove the use case:**
1. Delete `LoginUseCaseImpl.swift` and `LoginUseCase.swift`.
2. Accept that the VM is the orchestrator.
3. Less clean architecturally but eliminates the dead code.

---

## 4. Remove unused `Account` from flow state enum cases

**Priority:** Medium — unnecessary associated value adds noise.

**Problem:**
`LoginFlowState.vault(Account)` and `UnlockFlowState.vault(Account)` carry an `Account` value, but `RootViewModel.handleLoginFlow` and `handleUnlockFlow` never read it — they just match on `.vault` and set `screen = .vault`.

**Files affected:**
- `Presentation/Login/LoginViewModel.swift` (`LoginFlowState`)
- `Presentation/Unlock/UnlockViewModel.swift` (`UnlockFlowState`)
- `App/MacwardenApp.swift` (`RootViewModel`)

**Guidance:**
1. Change `.vault(Account)` → `.vault` (no associated value) in both enums.
2. Update all sites that construct `.vault(account)` → `.vault`.
3. Update pattern matches in `RootViewModel` (already just `case .vault:`).

---

## 5. Delete empty placeholder files

**Priority:** Medium — pure noise.

**Problem:**
`AppRootViewModel.swift` and `AppRootView.swift` contain only comments saying "this file is intentionally empty." They serve no purpose and clutter the project navigator.

**Files affected:**
- `App/AppRootViewModel.swift`
- `App/AppRootView.swift`

**Guidance:**
1. Delete both files.
2. Remove their references from `project.pbxproj`.

---

## 6. Simplify fingerprint nil-coalescing in `SSHKeyDetailView`

**Priority:** Low — readability improvement.

**Problem:**
```swift
let fingerprint = sshKey.keyFingerprint?.isEmpty == false
    ? sshKey.keyFingerprint
    : "[No fingerprint]"
```
The `?.isEmpty == false` ternary is hard to parse at a glance.

**File affected:**
- `Presentation/Vault/Detail/SSHKeyDetailView.swift`

**Guidance:**
Replace with:
```swift
let fingerprint: String
if let fp = sshKey.keyFingerprint, !fp.isEmpty {
    fingerprint = fp
} else {
    fingerprint = "[No fingerprint]"
}
```
Also update the copy closure guard to use the resolved value instead of re-checking the optional.

---

## 7. Make `relativeDateFormatter` static in `VaultBrowserView`

**Priority:** Low — minor performance improvement.

**Problem:**
`relativeDateFormatter` is a computed property that allocates a new `RelativeDateTimeFormatter` on every `body` evaluation.

**File affected:**
- `Presentation/Vault/VaultBrowserView.swift`

**Guidance:**
Change from:
```swift
private var relativeDateFormatter: RelativeDateTimeFormatter {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
}
```
To:
```swift
private static let relativeDateFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
}()
```
Update the call site to use `Self.relativeDateFormatter`.

---

## 8. Clean up `SidebarSelection` Equatable declaration

**Priority:** Low — cosmetic clarity.

**Problem:**
`SidebarSelection` declares `: Equatable` on the enum itself *and* provides an explicit `==` inside the `Hashable` extension. The compiler uses the explicit `==`, making the conformance on the enum line redundant.

**File affected:**
- `Domain/Entities/SidebarSelection.swift`

**Guidance:**
1. Remove `Equatable` from the enum declaration line (keep only `Hashable` extension with explicit `==` and `hash(into:)`).
2. The existing comment explains the `nonisolated` rationale — keep it.

---

## Summary

| # | Change | Impact | Risk |
|---|--------|--------|------|
| 1 | Extract `VerticalLabeledContentStyle` | Eliminates duplication | None |
| 2 | `ItemType.sfSymbol` extension | Eliminates duplication | None |
| 3 | Wire VM through `LoginUseCaseImpl` | Removes dead code + duplication | Low — test login flow |
| 4 | Drop `Account` from `.vault` cases | Removes unused data | None |
| 5 | Delete empty files | Reduces noise | None |
| 6 | Simplify fingerprint logic | Readability | None |
| 7 | Static date formatter | Avoids repeated allocation | None |
| 8 | Clean `SidebarSelection` conformance | Clarity | None |

All changes are behaviour-preserving. Items 1–3 should be done first as they address real duplication. Items 4–8 are polish and can be done in any order.
