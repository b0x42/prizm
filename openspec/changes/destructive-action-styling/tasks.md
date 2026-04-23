## 1. Move Delete into edit sheet

- [ ] 1.1 Expose `isEditing` computed property on `ItemEditViewModel` (true when `editUseCase != nil`)
- [ ] 1.2 Add `onDelete: ((String) async -> Void)?` closure to `ItemEditView`; add a red "Delete Item" button at the bottom of the form, hidden when `!viewModel.isEditing`; include `accessibilityIdentifier`
- [ ] 1.3 Wire confirmation alert in `ItemEditView`: on confirm, dismiss sheet then call `onDelete`
- [ ] 1.4 Pass `onDelete` closure from `VaultBrowserView` into `ItemEditView`, calling `viewModel.performSoftDelete`

## 2. Remove Delete from detail toolbar

- [ ] 2.1 Remove the soft-delete `ToolbarItem(placement: .destructiveAction)` and `showSoftDeleteAlert` from `VaultBrowserView`'s active-item detail toolbar
- [ ] 2.2 Remove `onSoftDelete` from `ItemDetailView` (permanent delete for trashed items stays)

## 3. Verify red styling on all destructive actions

- [ ] 3.1 Audit all destructive buttons and context menu items; ensure each uses `.foregroundStyle(.red)` or `role: .destructive`: Delete Folder, Delete Collection, Move to Trash, Delete Permanently (note: Empty Trash button is not yet implemented — out of scope)

## 4. Tests

- [ ] 4.1 Update existing delete-related UI tests to trigger soft-delete from the edit sheet instead of the detail toolbar
- [ ] 4.2 Add test: "Delete Item" button is not shown in edit sheet during item creation
- [ ] 4.3 Add test: detail toolbar does not contain Delete button for active items
