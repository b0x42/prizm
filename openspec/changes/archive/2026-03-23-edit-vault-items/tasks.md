## 1. Domain Layer — Mutable Draft Type

- [x] 1.1 Add `DraftLoginURI` mutable struct (mirrors `LoginURI` with `var` fields) to Domain/Entities
- [x] 1.2 Add `DraftCustomField` mutable struct (mirrors `CustomField` with `var` fields) to Domain/Entities
- [x] 1.3 Add `DraftItemContent` enum (mirrors `ItemContent` with mutable content structs) to Domain/Entities
- [x] 1.4 Add `DraftVaultItem` struct with `var` fields and `init(_ item: VaultItem)` convenience init
- [x] 1.5 Add `VaultItem.init(_ draft: DraftVaultItem)` init (draft → domain, used post-save)
- [x] 1.6 Write unit tests for `DraftVaultItem` ↔ `VaultItem` round-trip for all five item types

## 2. Domain Layer — Use Case Protocol

- [x] 2.1 Add `EditVaultItemUseCase` protocol to Domain/UseCases: `func execute(draft: DraftVaultItem) async throws -> VaultItem`
- [x] 2.2 Write failing unit test for `EditVaultItemUseCase` using a mock `VaultRepository`

## 3. Data Layer — Reverse Mapper

- [x] 3.1 Add `CipherMapper.toRawCipher(_ draft: DraftVaultItem, encryptedWith key: SymmetricKey) throws -> RawCipher` to CipherMapper
- [x] 3.2 Implement reverse mapping for Login content (name, username, password, URIs, notes, custom fields)
- [x] 3.3 Implement reverse mapping for Card content
- [x] 3.4 Implement reverse mapping for Identity content
- [x] 3.5 Implement reverse mapping for Secure Note content
- [x] 3.6 Implement reverse mapping for SSH Key content
- [x] 3.7 Write unit tests: round-trip for each item type (encrypt via reverse mapper → decrypt via existing mapper → compare)

## 4. Data Layer — Repository & API

- [x] 4.1 Add `update(_ draft: DraftVaultItem) async throws -> VaultItem` to `VaultRepository` protocol
- [x] 4.2 Add `PUT /ciphers/{id}` request method to `MacwardenAPIClient`
- [x] 4.3 Implement `VaultRepositoryImpl.update`: call reverse mapper, call API, decode response, update in-memory cache
- [x] 4.4 Write unit tests for `VaultRepositoryImpl.update` covering success path and API error path

## 5. Data Layer — Use Case Implementation

- [x] 5.1 Implement `EditVaultItemUseCaseImpl` (calls `VaultRepository.update`, returns `VaultItem`)
- [x] 5.2 Wire `EditVaultItemUseCaseImpl` into `AppContainer` (DI)
- [x] 5.3 Complete unit test from task 2.2 using the real `EditVaultItemUseCaseImpl` with mock repository

## 6. Presentation Layer — ViewModel

- [x] 6.1 Create `ItemEditViewModel`: holds `@Published var draft: DraftVaultItem`, save/cancel actions, loading and error state
- [x] 6.2 Implement `ItemEditViewModel.save()`: call use case, on success dismiss sheet and publish updated item; on failure publish error
- [x] 6.3 Implement unsaved-changes detection (`var hasChanges: Bool`) for cancel confirmation prompt

## 7. Presentation Layer — Edit Forms

- [x] 7.1 Create `LoginEditForm` SwiftUI view: Name, Username, Password, editable URI rows (existing only, with match-type picker per row), Notes, editable custom field rows (existing only)
- [x] 7.2 Create `CardEditForm` SwiftUI view: Name, Cardholder Name, Brand, Number, Expiry Month, Expiry Year, Security Code, Notes, editable custom field rows (existing only)
- [x] 7.3 Create `IdentityEditForm` SwiftUI view: Name + all identity fields grouped into sections matching the read-only card layout, Notes, editable custom field rows (existing only)
- [x] 7.4 Create `SecureNoteEditForm` SwiftUI view: Name, Note text, editable custom field rows (existing only)
- [x] 7.5 Create `SSHKeyEditForm` SwiftUI view: Name, Private Key (masked, with reveal toggle), Public Key, Notes, editable custom field rows (existing only); Key Fingerprint displayed as a read-only label (auto-derived, not editable)
- [x] 7.6 Create `CustomFieldsEditSection` reusable view: editable rows for existing custom fields only (no add/remove/reorder controls); Hidden-type fields masked with reveal toggle
- [x] 7.7 Ensure all edit form views use `DesignSystem` typography and spacing tokens (no hardcoded literals)

## 8. Presentation Layer — Edit Sheet Container

- [x] 8.1 Create `ItemEditView` sheet container: toolbar with Save and Discard buttons, dispatches to per-type form, shows inline error banner on failure; Save button label changes to "Saving…" while request is in-flight
- [x] 8.2 Add Name-required validation: disable Save and show error when Name field is empty
- [x] 8.3 Implement discard confirmation prompt (shown only when `hasChanges` is true), triggered by both Discard button and Esc key; prompt buttons: "Discard Changes" (destructive) and "Keep Editing"
- [x] 8.4 Add `.help("Discard changes (Esc)")` tooltip to the Discard button
- [x] 8.5 Add `.sheet` presentation to `ItemDetailView` triggered by an Edit toolbar button
- [x] 8.6 Add `AccessibilityIdentifiers` constants for Edit button, Save button, Discard button, and error banner
- [x] 8.7 Attach `.keyboardShortcut("e", modifiers: .command)` to the Edit button in `ItemDetailView` (active only when an item is selected)
- [x] 8.8 Attach `.keyboardShortcut("s", modifiers: .command)` to the Save button in `ItemEditView`
- [x] 8.9 Add `.onExitCommand` to the `ItemEditView` sheet content to invoke the same discard logic as the Discard button (handles Esc)
- [x] 8.10 Observe vault lock events in `ItemEditViewModel`; dismiss the edit sheet immediately (no confirmation) and clear `DraftVaultItem` when the vault locks
- [x] 8.11 Clear `DraftVaultItem` from memory on sheet dismiss (both save and discard paths) to satisfy Constitution §III plaintext minimisation
- [x] 8.12 Apply sensitive-field auto-mask timeout to revealed password (Login) and revealed private key (SSH Key) fields, consistent with the app-wide configurable timeout

## 9. Presentation Layer — "Item" Menu Bar Extra

- [x] 9.1 Create `MenuBarViewModel`: `@Published var isVaultUnlocked: Bool`, `@Published var canEdit: Bool` (item selected + sheet closed), `@Published var canSave: Bool` (sheet open + not saving); observes shared session and edit state
- [x] 9.2 Add a `MenuBarExtra("Item", ...)` scene to the app's `@main` body with `.menuBarExtraStyle(.menu)`, conditionally present when `isVaultUnlocked`
- [x] 9.3 Add "Edit" `Button` to the menu with `.keyboardShortcut("e", modifiers: .command)` (shows ⌘E in the dropdown); disabled when `!canEdit`
- [x] 9.4 Add "Save" `Button` to the menu with `.keyboardShortcut("s", modifiers: .command)` (shows ⌘S in the dropdown); disabled when `!canSave`
- [x] 9.5 Wire `MenuBarViewModel` into `AppContainer` and connect to vault/session/edit state publishers

## 10. UI Journey Tests

- [x] 10.1 Write `EditItemJourneyTests` XCUITest: open vault, select a Login item, tap Edit, change the name, tap Save, verify detail pane and list row show updated name
- [x] 10.2 Write XCUITest: open edit sheet, make a change, click Discard, click "Discard Changes" in the prompt, verify item is unchanged
- [x] 10.3 Write XCUITest: open edit sheet, clear the Name field, verify Save is disabled
- [x] 10.4 Write XCUITest: select an item, press ⌘E, verify edit sheet opens
- [x] 10.5 Write XCUITest: open edit sheet, make a change, press ⌘S, verify sheet dismisses and item updated
- [x] 10.6 Write XCUITest: open edit sheet with no changes, press Esc, verify sheet dismisses without prompt
- [x] 10.7 Write XCUITest: unlock vault, verify "Item" appears in menu bar; click Edit, verify edit sheet opens; lock vault, verify "Item" disappears

## 11. Code Comments & Documentation

- [x] 11.1 Add open-source standard comments to `DraftVaultItem` and all draft content types (explain WHY the mutable mirror pattern is used)
- [x] 11.2 Add security-critical comments to `CipherMapper.toRawCipher` (security goal, algorithm reference, what is NOT done)
- [x] 11.3 Add security-critical comments to `VaultRepositoryImpl.update` (data flow, re-encryption boundary)
- [x] 11.4 Add `// TODO:` comments for known deferred work: biometric re-auth before save, offline edit persistence
