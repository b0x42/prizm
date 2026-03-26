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
Encryption and upload SHALL execute on a background `Task`. While in progress, the confirmation sheet SHALL show a progress indicator and disable the Confirm and Cancel buttons. On success, the sheet SHALL dismiss. On failure, the sheet SHALL remain open with an inline error and re-enable the Cancel button.

#### Scenario: Progress indicator shown during upload
- **WHEN** the user confirms and upload begins
- **THEN** a progress indicator SHALL be visible and both Confirm and Cancel SHALL be disabled

#### Scenario: Upload failure shows inline error with Cancel re-enabled
- **WHEN** the upload fails (network error, server error, premium gate)
- **THEN** the confirmation sheet SHALL remain open with an inline error message and Cancel SHALL be re-enabled

#### Scenario: Premium gate error shown inline
- **WHEN** the server returns HTTP 402
- **THEN** the error "Attachments require a Bitwarden Premium account." SHALL be shown on the confirmation sheet

---

### Requirement: Vault lock during upload aborts and clears file data
If the vault locks while an upload is in progress, the system SHALL cancel the upload task, zero any in-memory file bytes and attachment key material, and dismiss the confirmation sheet without a discard prompt.

#### Scenario: Vault lock zeros in-flight file data
- **WHEN** the vault locks while upload is in progress
- **THEN** the upload task SHALL be cancelled, in-memory file bytes SHALL be zeroed, and the confirmation sheet SHALL dismiss immediately
