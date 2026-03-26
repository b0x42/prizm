## ADDED Requirements

### Requirement: Attachments section in detail pane lists all attachments
The vault item detail pane SHALL include an "Attachments" section below the existing field cards when a cipher has one or more attachments. Each row SHALL display the decrypted file name and human-readable file size. The section SHALL also contain an "Add Attachment" button (see `attachment-add-flow`). When a cipher has no attachments, the section SHALL still be present with only the "Add Attachment" button visible.

#### Scenario: Attachments section shows file name and size per row
- **WHEN** a vault item with attachments is selected
- **THEN** each attachment SHALL appear as a row showing its plaintext file name and size

#### Scenario: Attachments section shows Add Attachment button even with no attachments
- **WHEN** a vault item with no attachments is selected
- **THEN** an Attachments section SHALL be present containing only the "Add Attachment" button

---

### Requirement: Open decrypts and opens attachment in default app
Each attachment row SHALL have an "Open" action. Pressing it SHALL:
1. Download and decrypt the attachment on a background `Task`
2. Write the plaintext bytes to a temp file in a `FileManager`-managed temp directory
3. Open the temp file via `NSWorkspace.shared.open(_:)`
4. After 30 seconds, overwrite the temp file with zeroes and delete it

A row-level progress indicator SHALL be shown during download and decryption. If the operation fails, an inline error SHALL appear on the row.

#### Scenario: Open downloads, decrypts, and launches default app
- **WHEN** the user clicks "Open" on an attachment row
- **THEN** the system SHALL download and decrypt the file in the background and open it with the system default app for its file type

#### Scenario: Temp file is zeroed and deleted 30 seconds after open
- **WHEN** 30 seconds have elapsed after the temp file was written
- **THEN** the temp file SHALL be overwritten with zeroes and deleted

#### Scenario: Open failure shows inline row error
- **WHEN** download or decryption fails
- **THEN** an inline error SHALL appear on the attachment row; no temp file SHALL remain on disk

---

### Requirement: Save to Disk decrypts and saves via NSSavePanel
Each attachment row SHALL have a "Save to Disk" action. Pressing it SHALL open an `NSSavePanel` pre-filled with the original (decrypted) file name. After the user confirms a save location, the system SHALL download and decrypt the attachment on a background `Task` and write the plaintext to the chosen path. The in-memory plaintext buffer SHALL be zeroed immediately after the write completes.

#### Scenario: Save to Disk pre-fills original file name in NSSavePanel
- **WHEN** the user clicks "Save to Disk" on an attachment row
- **THEN** the `NSSavePanel` SHALL open with the attachment's decrypted file name pre-filled

#### Scenario: Plaintext written to user-chosen path and buffer zeroed
- **WHEN** the user confirms a save location
- **THEN** the decrypted bytes SHALL be written to that path and the in-memory buffer SHALL be zeroed immediately after

#### Scenario: Cancelling NSSavePanel writes nothing
- **WHEN** the user cancels the NSSavePanel
- **THEN** no file SHALL be written and no download SHALL be initiated

---

### Requirement: Delete attachment with confirmation
Each attachment row SHALL have a delete action. Selecting it SHALL present a confirmation alert: "Delete attachment "<fileName>"? This cannot be undone." Confirming SHALL call `DELETE /api/ciphers/{id}/attachment/{attachmentId}`; on success the row SHALL be removed from the list. Cancelling SHALL leave the attachment unchanged.

#### Scenario: Delete shows confirmation alert with file name
- **WHEN** the user triggers delete on an attachment row
- **THEN** an alert SHALL appear: "Delete attachment "<fileName>"? This cannot be undone."

#### Scenario: Confirmed delete removes row from detail pane
- **WHEN** the user confirms the delete alert and the server returns 200
- **THEN** the attachment row SHALL disappear from the Attachments section

#### Scenario: Cancelled delete leaves attachment unchanged
- **WHEN** the user dismisses the delete alert without confirming
- **THEN** the attachment SHALL remain in the list unchanged

#### Scenario: Delete server failure shows inline error
- **WHEN** the server returns a non-200 response for the delete
- **THEN** an inline error SHALL appear and the attachment SHALL remain visible
