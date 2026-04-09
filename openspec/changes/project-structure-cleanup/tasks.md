## 1. Gitignore & Cleanup

- [ ] 1.1 Add `.DS_Store` to `.gitignore` and remove tracked `.DS_Store` files (`git rm --cached`)
- [ ] 1.2 Delete top-level `Prizm_V1.icon/` duplicate (only `Prizm/Prizm_V1.icon/` is referenced by Xcode)
- [ ] 1.3 Delete empty `PrizmTests/PrizmTests.swift` placeholder

## 2. Test Directory Restructure

- [ ] 2.1 Create subdirectories: `PrizmTests/Domain/`, `PrizmTests/Data/`, `PrizmTests/Presentation/`, `PrizmTests/App/`
- [ ] 2.2 Move 9 Domain test files into `PrizmTests/Domain/` (DraftVaultItemTests, EntityValidationTests, AttachmentEntityTests, PasswordGeneratorTests, SearchVaultTests, DeleteRestoreVaultItemUseCaseTests, EditVaultItemUseCaseTests, GetLastSyncDateUseCaseTests, AttachmentUseCaseTests)
- [ ] 2.3 Move 18 Data test files into `PrizmTests/Data/` (AuthRepositoryImplTests, VaultRepositoryImplTests, VaultRepositoryImplDeleteRestoreTests, SyncRepositoryImplTests, SyncTimestampRepositoryImplTests, AttachmentRepositoryImplTests, CipherMapperTests, CipherMapperReverseTests, AttachmentMapperTests, PrizmCryptoServiceTests, AttachmentCryptoTests, EncStringTests, KeychainServiceTests, VaultKeyCacheTests, VaultKeyServiceImplTests, LoginUseCaseTests, UnlockUseCaseTests, ToggleFavoriteTests)
- [ ] 2.4 Move 15 Presentation test files into `PrizmTests/Presentation/` (LoginViewModelTests, UnlockViewModelTests, VaultBrowserViewModelGlobalSearchTests, VaultBrowserViewModelSyncStatusTests, PasswordGeneratorViewModelTests, AboutViewModelTests, AttachmentAddViewModelTests, AttachmentBatchViewModelTests, AttachmentRowViewModelTests, RootViewModelLockTests, SyncLabelFormatterTests, CardBackgroundTests, MaskedFieldViewTests, HighlightedTextTests, OptionKeyMonitorTests)
- [ ] 2.5 Move 1 App test file into `PrizmTests/App/` (AttachmentTempFileManagerTests)
- [ ] 2.6 Move `Tests/UITests/*.swift` into `PrizmTests/UITests/` and delete empty `Tests/` directory

## 3. Attachment Presentation Subfolder

- [ ] 3.1 Create `Presentation/Vault/Attachments/` and move 5 files: AttachmentAddViewModel, AttachmentBatchViewModel, AttachmentRowViewModel, AttachmentConfirmSheet, AttachmentBatchSheet

## 4. Xcode Project Cleanup

- [ ] 4.1 Update `project.pbxproj` file reference paths for all moved test files
- [ ] 4.2 Update `project.pbxproj` file reference paths for moved attachment files
- [ ] 4.3 Remove phantom groups from pbxproj: `DomainTests`, `DataTests`, `PresentationTests` under `Tests/`
- [ ] 4.4 Remove `Recovered References` group from pbxproj
- [ ] 4.5 Add new PBXGroup entries: `PrizmTests/Domain`, `Data`, `Presentation`, `App`, `UITests`; `Presentation/Vault/Attachments`

## 5. Constitution Update

- [ ] 5.1 Update CONSTITUTION.md §III: `BitwardenCryptoService` → `PrizmCryptoService` (and `BitwardenCryptoServiceImpl` in External Dependencies §Argon2Swift)
- [ ] 5.2 Bump Constitution version to 1.4.3 (PATCH — naming clarification)

## 6. Verify

- [ ] 6.1 Build succeeds (`xcodebuild build`)
- [ ] 6.2 All unit tests pass (`xcodebuild test`)
