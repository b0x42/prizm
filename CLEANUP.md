# Project Structure Cleanup Plan

## Issues

1. **Duplicate `Prizm_V1.icon`** — identical at top-level and inside `Prizm/`. Only the inner copy is referenced by Xcode.
2. **Flat test directory** — 43 unit test files dumped in `PrizmTests/` with no layer organization.
3. **Split test locations** — unit tests in `PrizmTests/`, UI tests in `Tests/UITests/`. Phantom groups (`Tests/DomainTests`, `Tests/DataTests`, `Tests/PresentationTests`) exist in pbxproj but not on disk.
4. **Attachment files crowding `Presentation/Vault/`** — 5 attachment files loose alongside main vault views, while other concerns already have subfolders.

## Steps

### 1. Delete top-level `Prizm_V1.icon` duplicate

Remove `./Prizm_V1.icon/`. The Xcode project references `./Prizm/Prizm_V1.icon/`.

### 2. Create test subdirectories mirroring source layers

```
PrizmTests/
  Domain/
  Data/
  Presentation/
  App/
```

### 3. Move unit test files into layer subdirectories

**Domain (9 files):**
- DraftVaultItemTests.swift
- EntityValidationTests.swift
- AttachmentEntityTests.swift
- PasswordGeneratorTests.swift
- SearchVaultTests.swift
- DeleteRestoreVaultItemUseCaseTests.swift
- EditVaultItemUseCaseTests.swift
- GetLastSyncDateUseCaseTests.swift
- AttachmentUseCaseTests.swift

**Data (18 files):**
- AuthRepositoryImplTests.swift
- VaultRepositoryImplTests.swift
- VaultRepositoryImplDeleteRestoreTests.swift
- SyncRepositoryImplTests.swift
- SyncTimestampRepositoryImplTests.swift
- AttachmentRepositoryImplTests.swift
- CipherMapperTests.swift
- CipherMapperReverseTests.swift
- AttachmentMapperTests.swift
- PrizmCryptoServiceTests.swift
- AttachmentCryptoTests.swift
- EncStringTests.swift
- KeychainServiceTests.swift
- VaultKeyCacheTests.swift
- VaultKeyServiceImplTests.swift
- LoginUseCaseTests.swift
- UnlockUseCaseTests.swift
- ToggleFavoriteTests.swift

**Presentation (15 files):**
- LoginViewModelTests.swift
- UnlockViewModelTests.swift
- VaultBrowserViewModelGlobalSearchTests.swift
- VaultBrowserViewModelSyncStatusTests.swift
- PasswordGeneratorViewModelTests.swift
- AboutViewModelTests.swift
- AttachmentAddViewModelTests.swift
- AttachmentBatchViewModelTests.swift
- AttachmentRowViewModelTests.swift
- RootViewModelLockTests.swift
- SyncLabelFormatterTests.swift
- CardBackgroundTests.swift
- MaskedFieldViewTests.swift
- HighlightedTextTests.swift
- OptionKeyMonitorTests.swift

**App (1 file):**
- AttachmentTempFileManagerTests.swift

### 4. Keep `Mocks/` in place

`PrizmTests/Mocks/` stays as-is — already properly organized.

### 5. Delete empty `PrizmTests.swift` placeholder

### 6. Move UITests into `PrizmTests/UITests/`

Move `Tests/UITests/*.swift` → `PrizmTests/UITests/`. Delete the now-empty `Tests/` directory.

### 7. Create `Presentation/Vault/Attachments/` subfolder

Move into `Presentation/Vault/Attachments/`:
- AttachmentAddViewModel.swift
- AttachmentBatchViewModel.swift
- AttachmentRowViewModel.swift
- AttachmentConfirmSheet.swift
- AttachmentBatchSheet.swift

### 8. Update `project.pbxproj`

- Rewrite file reference paths for all moved files
- Remove phantom `Tests/` group and its empty subgroups
- Remove `Recovered References` group
- Add new `PrizmTests/Domain`, `Data`, `Presentation`, `App`, `UITests` groups
- Add `Presentation/Vault/Attachments` group

### 9. Verify build succeeds

Run `xcodebuild` to confirm the project compiles after restructuring.
