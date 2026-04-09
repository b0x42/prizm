## Why

The project has accumulated structural debt: 43 test files in a flat directory, a duplicate icon folder, phantom Xcode groups pointing to nonexistent directories, a stale `Recovered References` group, loose attachment files in the Vault presentation folder, and a naming mismatch between the Constitution (`BitwardenCryptoService`) and the codebase (`PrizmCryptoService`). This makes navigation harder and violates the Constitution's simplicity principle (§VI: "delete unused code").

## What Changes

- Delete duplicate top-level `Prizm_V1.icon/` (only `Prizm/Prizm_V1.icon/` is referenced)
- Organize `PrizmTests/` into layer subdirectories: `Domain/`, `Data/`, `Presentation/`, `App/`
- Move `Tests/UITests/` into `PrizmTests/UITests/` and delete empty `Tests/` directory
- Move 5 loose attachment files into `Presentation/Vault/Attachments/`
- Delete empty `PrizmTests.swift` placeholder
- Clean `project.pbxproj`: remove phantom groups (`DomainTests`, `DataTests`, `PresentationTests`), remove `Recovered References`, update all moved file paths
- Add `.DS_Store` to `.gitignore` and remove tracked `.DS_Store` files
- Update Constitution §III to reference `PrizmCryptoService` instead of `BitwardenCryptoService` (the codebase was renamed; the Constitution was not updated)

## Capabilities

### New Capabilities

_None — this is a structural refactor with no new features._

### Modified Capabilities

_None — no spec-level behavior changes._

## Impact

- **Xcode project**: `project.pbxproj` rewritten for all moved files and removed groups
- **All test imports**: No import changes needed (tests don't import by directory path)
- **Constitution**: §III and External Dependencies section updated for naming consistency
- **Git history**: Large rename commit; `git log --follow` preserves per-file history
