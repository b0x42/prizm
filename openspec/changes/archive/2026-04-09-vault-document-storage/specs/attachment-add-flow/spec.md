## ADDED Requirements

### Requirement: User can attach a file to any vault item
The system SHALL provide an "Add Attachment" button in the vault item detail pane for all cipher types (Login, Card, Identity, Secure Note, SSH Key). Clicking it SHALL open an `NSOpenPanel` allowing the user to select a single file of any type. After selection, a confirmation sheet SHALL display the file name and file size. The user SHALL be able to confirm or cancel. Confirming SHALL encrypt and upload the attachment; on success the new attachment SHALL appear in the detail pane's Attachments section.

#### Scenario: Add Attachment button is present on all cipher types
- **WHEN** any vault item detail pane is shown
- **THEN** an "Add Attachment" button SHALL be visible

#### Scenario: File picker opens on button click
- **WHEN** the user clicks "Add Attachment"
- **THEN** an `NSOpenPanel` SHALL open allowing selection of any single file

#### Scenario: Confirmation sheet shows file name and size
- **WHEN** the user selects a file
- **THEN** a sheet SHALL display the selected file name and a human-readable size (e.g., "3.4 MB")

#### Scenario: Confirming uploads and shows attachment in detail pane
- **WHEN** the user confirms the sheet and the upload succeeds
- **THEN** the new attachment SHALL appear in the Attachments section of the detail pane without a full re-sync

#### Scenario: Cancelling the confirmation sheet leaves no attachment
- **WHEN** the user cancels the confirmation sheet
- **THEN** no upload SHALL be initiated and the detail pane SHALL be unchanged

---

### Requirement: Files larger than 500 MB are rejected before upload
The system SHALL check the selected file's size before reading any bytes into memory. If the size exceeds 500 MB (524 288 000 bytes), a size warning SHALL be shown on the confirmation sheet and the Confirm button SHALL be disabled. Files between 50 MB and 500 MB SHALL show an inline advisory ("Large file — upload may take a moment") but SHALL NOT be blocked.

#### Scenario: File over 500 MB shows error and disables Confirm
- **WHEN** the user selects a file larger than 500 MB
- **THEN** the confirmation sheet SHALL display "This file is too large. Attachments must be 500 MB or smaller." and the Confirm button SHALL be disabled

#### Scenario: File between 50 MB and 500 MB shows size advisory
- **WHEN** the user selects a file between 50 MB and 500 MB
- **THEN** the confirmation sheet SHALL show "Large file — upload may take a moment" but the Confirm button SHALL remain enabled

#### Scenario: File at exactly 500 MB is accepted
- **WHEN** the user selects a file of exactly 524 288 000 bytes
- **THEN** the Confirm button SHALL be enabled with no size error

---

### Requirement: Upload runs on a background task with progress indicator
Encryption and upload SHALL execute on a background `Task`. While in progress, the confirmation sheet SHALL show a progress indicator and disable the Confirm button; the Cancel button SHALL remain enabled. On success, the sheet SHALL dismiss. On failure, the sheet SHALL remain open with an inline error.

#### Scenario: Progress indicator shown during upload
- **WHEN** the user confirms and upload begins
- **THEN** a progress indicator SHALL be visible and the Confirm button SHALL be disabled; Cancel SHALL remain enabled

#### Scenario: Cancel during upload aborts and clears file data
- **WHEN** the user presses Cancel while upload is in progress
- **THEN** the upload task SHALL be cancelled, the in-memory file data buffer SHALL be zeroed, and the sheet SHALL dismiss immediately

#### Scenario: Upload failure shows inline error with Cancel enabled
- **WHEN** the upload fails (network error, server error, premium gate)
- **THEN** the confirmation sheet SHALL remain open with an inline error message and Cancel SHALL be enabled

#### Scenario: Premium gate error shown inline
- **WHEN** the server returns HTTP 402
- **THEN** the error "Attachments require a Bitwarden Premium account." SHALL be shown on the confirmation sheet

---

### Requirement: Attachments section accepts dropped files
The Attachments section card SHALL act as a drop zone for files dragged from Finder or any other source. The system SHALL use SwiftUI's `.onDrop(of: [.fileURL], isTargeted:, perform:)` modifier — no AppKit drop target is needed. When one or more files are dragged over the Attachments section, the card SHALL display a visible highlight (e.g. a coloured border or background tint) to indicate it is a valid drop target. Dropping one or more files SHALL open a batch confirmation sheet listing all dropped files.

#### Scenario: Attachments card highlights when files are dragged over it
- **WHEN** the user drags one or more files over the Attachments section card
- **THEN** the card SHALL display a drop-target highlight and the cursor SHALL change to indicate a valid drop

#### Scenario: Dropping files opens the batch confirmation sheet
- **WHEN** the user drops one or more files onto the Attachments section card
- **THEN** a batch confirmation sheet SHALL open listing every dropped file

#### Scenario: Dragging non-file content over the card shows no highlight
- **WHEN** the user drags content that is not a file URL (e.g. text, an image from a web page)
- **THEN** the card SHALL NOT highlight and the drop SHALL be rejected

---

### Requirement: Batch confirmation sheet for drag-and-drop uploads
When files are dropped, the system SHALL present a single sheet listing all dropped files before any upload begins. Each file SHALL appear as a row showing its name and `sizeName`. Files exceeding 500 MB SHALL show an inline per-row error ("Too large — 500 MB max") and SHALL be excluded from the upload. The Confirm button SHALL be enabled if at least one dropped file is valid; it SHALL be disabled only if every file exceeds the limit. Confirming SHALL encrypt and upload all valid files concurrently on background `Task`s. The sheet SHALL remain open showing per-file upload state until all uploads complete or fail, then dismiss automatically on full success or remain open to show failures.

#### Scenario: Batch sheet lists all dropped files with name and size
- **WHEN** the batch confirmation sheet opens after a drop
- **THEN** every dropped file SHALL appear as a row showing its file name and `sizeName`

#### Scenario: Oversized files are flagged inline but do not block valid files
- **WHEN** the batch sheet contains a mix of valid files and files over 500 MB
- **THEN** each oversized file row SHALL show "Too large — 500 MB max" and SHALL be marked as excluded
- **AND** the Confirm button SHALL be enabled for the remaining valid files

#### Scenario: Confirm is disabled when every dropped file exceeds 500 MB
- **WHEN** all files in the batch sheet exceed 500 MB
- **THEN** the Confirm button SHALL be disabled

#### Scenario: Confirming starts concurrent uploads for all valid files
- **WHEN** the user confirms the batch sheet
- **THEN** each valid file SHALL begin encrypting and uploading on its own background `Task` concurrently
- **AND** each row SHALL show an individual progress indicator

#### Scenario: Per-file upload success removes the progress indicator from that row
- **WHEN** a file in the batch uploads successfully
- **THEN** its row SHALL show a success indicator and the attachment SHALL appear in the detail pane

#### Scenario: Per-file upload failure shows an inline row error
- **WHEN** a file in the batch fails to upload
- **THEN** its row SHALL show an inline error message; other files in the batch are not affected

#### Scenario: Sheet dismisses automatically when all uploads succeed
- **WHEN** every valid file in the batch has uploaded successfully
- **THEN** the sheet SHALL dismiss and all new attachments SHALL be visible in the Attachments section

#### Scenario: Sheet stays open if any upload fails
- **WHEN** at least one file in the batch fails to upload
- **THEN** the sheet SHALL remain open showing the failure rows; the user SHALL be able to dismiss manually

#### Scenario: Cancel before confirming discards all dropped file data
- **WHEN** the user presses Cancel on the batch confirmation sheet before confirming
- **THEN** no uploads SHALL be initiated and all in-memory file references SHALL be released

#### Scenario: Cancel while uploads are in progress cancels all tasks
- **WHEN** the user presses Cancel on the batch confirmation sheet after confirming (while uploads are running)
- **THEN** all in-flight upload tasks SHALL be cancelled, in-memory file bytes SHALL be zeroed, and the sheet SHALL dismiss immediately; any partially uploaded files SHALL appear as "Upload incomplete" on the next sync

---

### Requirement: Reject concurrent drag-drop while batch upload is in progress
While a batch upload is actively running (at least one upload task is in flight), the Attachments section drop zone SHALL NOT accept a new drop. When the user drags files over the card during an active upload, the card SHALL display a rejection indicator instead of the normal drop-target highlight, and the drop SHALL be ignored.

#### Scenario: Drop is rejected while uploads are in progress
- **WHEN** the user drops files onto the Attachments card while a batch upload is running
- **THEN** the drop SHALL be ignored and a brief inline message SHALL indicate that an upload is already in progress

---

### Requirement: Vault lock during upload aborts and clears file data
If the vault locks while an upload is in progress, the system SHALL cancel the upload task, zero any in-memory file bytes and attachment key material, and dismiss the confirmation sheet without a discard prompt.

#### Scenario: Vault lock zeros in-flight file data
- **WHEN** the vault locks while upload is in progress
- **THEN** the upload task SHALL be cancelled, in-memory file bytes SHALL be zeroed, and the confirmation sheet SHALL dismiss immediately

---

### Requirement: Add Attachment button shows picking state while file panel is open
`AttachmentAddViewModel` SHALL expose a `isPickingFile: Bool` property that is `true` while `NSOpenPanel.runModal()` is executing and `false` at all other times. `AttachmentsSectionView` SHALL accept an `isPicking: Bool` parameter and, when `true`, SHALL disable the "Add Attachment" button and replace the paperclip icon with a small `ProgressView` so the UI does not appear unresponsive during the NSOpenPanel blocking call.

`selectFile()` SHALL be declared `async`. The implementation SHALL call `await Task.yield()` after setting `isPickingFile = true` and before invoking `NSOpenPanel.runModal()`, giving SwiftUI one render pass to display the spinner before the main thread is blocked. The call site in `ItemDetailView` SHALL invoke `selectFile()` inside a `Task { await vm.selectFile() }` so the button action returns immediately and the async work proceeds on the main actor.

#### Scenario: Button disables while panel is open
- **WHEN** the user clicks "Add Attachment"
- **THEN** `isPickingFile` SHALL be set to `true` and SwiftUI SHALL render the spinner before `NSOpenPanel` opens
- **AND** the "Add Attachment" button SHALL be disabled and show a spinner

#### Scenario: Button re-enables after file selected
- **WHEN** the user picks a file and `NSOpenPanel` returns
- **THEN** `isPickingFile` SHALL be set to `false`
- **AND** the "Add Attachment" button SHALL re-enable

#### Scenario: Button re-enables after cancel
- **WHEN** the user cancels `NSOpenPanel` without selecting a file
- **THEN** `isPickingFile` SHALL be set to `false`
- **AND** the "Add Attachment" button SHALL re-enable

---

### Requirement: Attachment list refreshes immediately after upload sheet dismisses
After either the single-file confirm sheet or the batch upload sheet is dismissed, the detail pane SHALL immediately reflect the updated attachment list — newly uploaded attachments SHALL appear without requiring navigation away or a full vault sync.

#### Scenario: Single-file upload — attachment appears after confirm sheet dismisses
- **WHEN** the user confirms a single-file upload and the confirm sheet dismisses
- **THEN** the attachment section card SHALL update to show the newly uploaded attachment row

#### Scenario: Batch upload — attachments appear after batch sheet dismisses
- **WHEN** all batch uploads succeed and the batch sheet auto-dismisses
- **THEN** the attachment section card SHALL update to show all newly uploaded attachment rows

#### Scenario: Cancel does not break the section
- **WHEN** the user cancels an upload sheet without uploading
- **THEN** the attachment section card SHALL remain unchanged and no error SHALL be shown
