## 1. Domain layer

- [x] 1.1 Add `DraftVaultItem.blank(type: ItemType)` static factory that returns a blank draft with `UUID().uuidString` as placeholder ID, empty name, `isFavorite: false`, `isDeleted: false`, current date for creation/revision, `reprompt: 0`, and type-appropriate empty content (Login: blank username/password/no URIs/no TOTP; Card: all nil; Identity: all nil; SecureNote: nil notes; SSHKey: nil keys)
- [x] 1.2 Add `CreateVaultItemUseCase` protocol in `Domain/UseCases/` with `func execute(draft: DraftVaultItem) async throws -> VaultItem`
- [x] 1.3 Add `CreateVaultItemUseCaseImpl` in `Data/UseCases/` that delegates to `VaultRepository.create(_:)`

## 2. Data layer

- [x] 2.1 Add `createCipher(cipher: RawCipher) async throws -> RawCipher` to `PrizmAPIClientProtocol` — `POST /api/ciphers` with JSON body, returns the server-created cipher
- [x] 2.2 Implement `createCipher` in `PrizmAPIClientImpl` — authenticated POST with `baseRequest`, JSON-encode the `RawCipher`, decode the response
- [x] 2.3 Add `create(_ draft: DraftVaultItem) async throws -> VaultItem` to `VaultRepository` protocol
- [x] 2.4 Implement `create` in `VaultRepositoryImpl` — obtain keys, call `mapper.toRawCipher`, call `apiClient.createCipher`, map response, append to cache, return server-confirmed item

## 3. Presentation layer

- [x] 3.1 Add `newItemBar` to `VaultBrowserView` view body (not a ToolbarItem) — a `Button` + `.popover(NewItemTypePickerView)` embedded in the `else` branch of the Trash conditional so it is simply not rendered in Trash; stable position regardless of column focus because it is a plain view, not a toolbar item
- [x] 3.2 Add `createItem(type:)` method to `VaultBrowserViewModel` that creates a blank draft and presents the edit sheet in create mode
- [x] 3.3 Adapt `ItemEditViewModel` to accept an optional `VaultItem?` — when `nil`, use `CreateVaultItemUseCase` instead of `EditVaultItemUseCase` for save
- [x] 3.4 Add `makeItemCreateViewModel(for type: ItemType)` factory to `AppContainer`

## 4. Mock & wiring

- [x] 4.1 Add `createCipher` stub to `MockPrizmAPIClient`
- [x] 4.2 Add `create` stub to `MockVaultRepository`
- [x] 4.3 Wire `CreateVaultItemUseCaseImpl` in `AppContainer`

## 5. Blank Login URI

- [x] 5.1 Change `DraftVaultItem.blank(type: .login)` to include one empty `DraftLoginURI` (blank URI, nil match type) so the Website field is pre-expanded with match type hidden

## 6. Password field focus and input

- [x] 6.1 Replace static `Text` placeholder in `MaskedEditFieldRow` with `SecureField` when masked, so the password field is focusable via Tab and accepts direct keyboard input

## 7. ⌘N keyboard shortcut

- [x] 7.1 Replace `Menu` in `newItemBar` with `Button` + `.popover(NewItemTypePickerView)` so `.keyboardShortcut("n")` lives on the trigger only and does not annotate individual item-type rows
- [x] 7.2 Add `NewItemTypePickerView` — `List` with single-selection binding, pre-selects Login on open, ↑/↓ via native List, Enter confirms via `.onKeyPress(.return)`
- [x] 7.3 Add `testCmdN_opensPicker_inNonTrashCategory` to `CreateItemJourneyTests` — press ⌘N, assert the type picker menu appears (check for "Login" menu item)
- [x] 7.4 Add `testCmdN_isNoOp_inTrash` to `CreateItemJourneyTests` — select Trash, press ⌘N, assert no type picker / edit sheet appears
- [x] 7.5 Add `testCmdN_thenEnter_opensLoginSheet` to `CreateItemJourneyTests` — press ⌘N then Enter, assert the Login edit sheet opens (check for Save button)
