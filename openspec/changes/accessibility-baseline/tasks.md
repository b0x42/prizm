## 1. Icon-Only Button Labels — Vault Browser & Detail

- [ ] 1.1 Add `.accessibilityLabel("Settings")` to the gear `SettingsLink` in `VaultBrowserView`
- [ ] 1.2 Add `.accessibilityLabel("New Item")` to the plus `Menu` button in `VaultBrowserView`
- [ ] 1.3 Add `.accessibilityLabel(item.isFavorite ? "Unfavorite" : "Favorite")` and `.accessibilityValue(item.isFavorite ? "Favorited" : "Not favorited")` to the star button in `VaultBrowserView`
- [ ] 1.4 Add `.accessibilityLabel("Dismiss")` to the xmark sync error dismiss button in `VaultBrowserView`
- [ ] 1.5 Verify VoiceOver announces "Edit, button" on the Edit toolbar button (text label — no code change expected)
- [ ] 1.6 Verify VoiceOver announces "Restore, button" and "Delete Permanently, button" on trash toolbar buttons (text labels — no code change expected)

## 2. Icon-Only Button Labels — Field & Masked Field Components

- [ ] 2.1 Add `.accessibilityLabel("Copy \(label)")` and `.accessibilityHint("Copies to clipboard")` to the copy button in `FieldRowView`
- [ ] 2.2 Add `.accessibilityLabel("Open \(label)")` and `.accessibilityHint("Opens in browser")` to the open-URL button in `FieldRowView`
- [ ] 2.3 Add `.accessibilityLabel(isRevealed ? "Hide \(label)" : "Reveal \(label)")` to the reveal toggle in `MaskedFieldView`

## 3. Icon-Only Button Labels — Attachments

- [ ] 3.1 Add `.accessibilityLabel("Open")` to the open button in `AttachmentRowView`
- [ ] 3.2 Add `.accessibilityLabel("Save to Disk")` and `.accessibilityHint("Saves file to your chosen location")` to the save button in `AttachmentRowView`
- [ ] 3.3 Add `.accessibilityLabel("Delete")` to the delete button in `AttachmentRowView`
- [ ] 3.4 Add `.accessibilityLabel("Add Attachment")` to the add button in `AttachmentsSectionView`

## 4. Icon-Only Button Labels — Edit Forms, Password Generator & Sidebar

- [ ] 4.1 Add `.accessibilityLabel("Generate Password")` to the gearshape button in `LoginEditForm`
- [ ] 4.2 Add `.accessibilityLabel("Generate new password")` to the refresh button in `PasswordGeneratorView`
- [ ] 4.3 Add `.accessibilityLabel("Copy password")` and `.accessibilityHint("Copies to clipboard")` to the copy button in `PasswordGeneratorView`
- [ ] 4.4 Add `.accessibilityLabel("Remove")` to any xmark/minus icon buttons in `EditFieldRow` and `CustomFieldsEditSection`
- [ ] 4.5 Add `.accessibilityLabel("New Folder")` to the `folder.badge.plus` button in `SidebarView`

## 5. Decorative Images — Hidden from Accessibility Tree

- [ ] 5.1 Add `.accessibilityHidden(true)` to the favicon `Image` in `FaviconView`
- [ ] 5.2 Add `.accessibilityHidden(true)` to the large lock icon in `LoginView`
- [ ] 5.3 Add `.accessibilityHidden(true)` to the large lock icon in `UnlockView`
- [ ] 5.4 Add `.accessibilityHidden(true)` to the large icon in `TOTPPromptView`
- [ ] 5.5 Add `.accessibilityHidden(true)` to the large biometry icon in `BiometricEnrollmentPromptView`
- [ ] 5.6 Add `.accessibilityHidden(true)` to status indicator icons (checkmark, xmark, warning triangle, info circle) in `AttachmentBatchSheet` and `AttachmentConfirmSheet`

## 6. Section Header Traits

- [ ] 6.1 Add `.accessibilityAddTraits(.isHeader)` to the section header label in `DetailSectionCard` / `CardBackground` or wherever section titles are rendered in the detail view
- [ ] 6.2 Verify VoiceOver heading navigation (VO+Command+H) cycles through section headers

## 7. VoiceOver Announcements for Transient State

- [ ] 7.1 Post `AccessibilityNotification.Announcement` when the sync error banner appears in `VaultBrowserView`
- [ ] 7.2 Post `AccessibilityNotification.Announcement` when an action error is set on `VaultBrowserViewModel`

## 8. Accessibility Conformance Statement

- [ ] 8.1 Create `ACCESSIBILITY.md` at repo root with EN 301 549 / WCAG 2.1 Level AA conformance table in VPAT 2.4 Rev format covering all Level AA success criteria; mark known gaps honestly (contrast not audited, drag-and-drop lacks keyboard alternative)
- [ ] 8.2 Add link to `ACCESSIBILITY.md` in `README.md` (e.g. in the Privacy & Security section or as a new Accessibility section)
- [ ] 8.3 Add note to `DEVELOPMENT.md` requiring `accessibilityLabel` on all new icon-only buttons

## 9. Accessibility Verification Tests

- [ ] 9.1 XCUITest: verify key icon-only buttons have non-empty `accessibilityLabel` (settings gear, new item, copy, favorite star)
- [ ] 9.2 XCUITest: verify favorite star `accessibilityValue` changes between "Favorited" and "Not favorited" on toggle
