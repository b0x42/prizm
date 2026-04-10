## Context

Prizm's source is well-layered (Domain/Data/Presentation) but the test directory is flat (43 files), attachment views are loose in `Presentation/Vault/`, and the Xcode project has stale groups. The Constitution references `BitwardenCryptoService` but the code uses `PrizmCryptoService`.

## Goals / Non-Goals

**Goals:**
- Mirror source layer structure in test directory
- Group attachment presentation files into a subfolder
- Remove all dead references from the Xcode project
- Fix Constitution naming mismatch

**Non-Goals:**
- Refactoring any Swift code (pure file moves)
- Changing test target membership or build settings
- Renaming any Swift types or protocols

## Decisions

### Decision 1: Test subdirectories mirror source layers

```
PrizmTests/
  Domain/     ← entity, use case, utility tests
  Data/       ← repository, mapper, crypto, keychain, API tests
  Presentation/ ← view model, UI component tests
  App/        ← app-level tests (TempFileManager)
  UITests/    ← moved from Tests/UITests/
  Mocks/      ← stays in place
```

**Rationale**: Matches the source layer structure (Constitution §II). Finding the test for a source file becomes predictable: `Data/Crypto/PrizmCryptoService.swift` → `PrizmTests/Data/PrizmCryptoServiceTests.swift`.

### Decision 2: Attachment views into Presentation/Vault/Attachments/

Move `AttachmentAddViewModel`, `AttachmentBatchViewModel`, `AttachmentRowViewModel`, `AttachmentConfirmSheet`, `AttachmentBatchSheet` into `Presentation/Vault/Attachments/`. This matches the existing pattern where `Edit/`, `Detail/`, `Sidebar/`, `ItemList/` are subfolders.

### Decision 3: Single atomic commit for file moves

All file moves and pbxproj updates in one commit. This keeps `git bisect` clean — the project builds at every commit.

### Decision 4: Constitution update is a separate commit

The `BitwardenCryptoService` → `PrizmCryptoService` naming fix in CONSTITUTION.md is a PATCH version bump (clarification, not behavioral change). Separate commit for clean changelog.

## Risks / Trade-offs

**[Risk] pbxproj corruption during mass file moves** → Mitigation: Script the pbxproj path updates rather than manual editing. Verify build + tests after.

**[Trade-off] Large rename commit makes git blame noisier** → Accepted: `git log --follow` preserves per-file history. Long-term navigability outweighs short-term blame noise.
