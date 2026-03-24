## 1. Domain layer

- [x] 1.1 Add `DraftVaultItem.blank(type: ItemType)` static factory that returns a blank draft with `UUID().uuidString` as placeholder ID, empty name, `isFavorite: false`, `isDeleted: false`, current date for creation/revision, `reprompt: 0`, and type-appropriate empty content (Login: blank username/password/no URIs/no TOTP; Card: all nil; Identity: all nil; SecureNote: nil notes; SSHKey: nil keys)
- [x] 1.2 Add `CreateVaultItemUseCase` protocol in `Domain/UseCases/` with `func execute(draft: DraftVaultItem) async throws -> VaultItem`
- [x] 1.3 Add `CreateVaultItemUseCaseImpl` in `Data/UseCases/` that delegates to `VaultRepository.create(_:)`

## 2. Data layer

- [x] 2.1 Add `createCipher(cipher: RawCipher) async throws -> RawCipher` to `MacwardenAPIClientProtocol` — `POST /api/ciphers` with JSON body, returns the server-created cipher
- [x] 2.2 Implement `createCipher` in `MacwardenAPIClientImpl` — authenticated POST with `baseRequest`, JSON-encode the `RawCipher`, decode the response
- [x] 2.3 Add `create(_ draft: DraftVaultItem) async throws -> VaultItem` to `VaultRepository` protocol
- [x] 2.4 Implement `create` in `VaultRepositoryImpl` — obtain keys, call `mapper.toRawCipher`, call `apiClient.createCipher`, map response, append to cache, return server-confirmed item

## 3. Presentation layer

- [x] 3.1 Add `+` button to `VaultBrowserView` content column toolbar (above the item list, next to the search bar) — `Menu` with SF Symbol `plus` listing Login, Card, Identity, Secure Note, SSH Key; permanently anchored on the always-present `VStack` (not on `ItemListView`) so the `ToolbarItem` stays registered across category switches; hidden in Trash via `.opacity(0)` + `.allowsHitTesting(false)` to avoid toolbar placement drift
- [x] 3.2 Add `createItem(type:)` method to `VaultBrowserViewModel` that creates a blank draft and presents the edit sheet in create mode
- [x] 3.3 Adapt `ItemEditViewModel` to accept an optional `VaultItem?` — when `nil`, use `CreateVaultItemUseCase` instead of `EditVaultItemUseCase` for save
- [x] 3.4 Add `makeItemCreateViewModel(for type: ItemType)` factory to `AppContainer`

## 4. Mock & wiring

- [x] 4.1 Add `createCipher` stub to `MockMacwardenAPIClient`
- [x] 4.2 Add `create` stub to `MockVaultRepository`
- [x] 4.3 Wire `CreateVaultItemUseCaseImpl` in `AppContainer`

## 5. Blank Login URI

- [x] 5.1 Change `DraftVaultItem.blank(type: .login)` to include one empty `DraftLoginURI` (blank URI, nil match type) so the Website field is pre-expanded with match type hidden

## 6. Password field focus and input

- [x] 6.1 Replace static `Text` placeholder in `MaskedEditFieldRow` with `SecureField` when masked, so the password field is focusable via Tab and accepts direct keyboard input

## 7. ⌘N keyboard shortcut

- [x] 7.1 Add `.keyboardShortcut(.n, modifiers: .command)` to the `Menu` in `VaultBrowserView` so ⌘N opens the type picker
- [x] 7.2 Add `.disabled(viewModel.sidebarSelection == .trash)` to the same `Menu` so ⌘N is a no-op in Trash and the menu bar entry is greyed out
- [x] 7.3 Add `testCmdN_opensPicker_inNonTrashCategory` to `CreateItemJourneyTests` — press ⌘N, assert the type picker menu appears (check for "Login" menu item)
- [x] 7.4 Add `testCmdN_isNoOp_inTrash` to `CreateItemJourneyTests` — select Trash, press ⌘N, assert no type picker / edit sheet appears
- [x] 7.5 Add `testCmdN_thenEnter_opensLoginSheet` to `CreateItemJourneyTests` — press ⌘N then Enter, assert the Login edit sheet opens (check for Save button)
