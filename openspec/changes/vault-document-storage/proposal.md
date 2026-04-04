## Why

Users need a secure place to store sensitive files (PDFs, images, documents) alongside their vault credentials. Bitwarden and Vaultwarden both provide a first-class **Attachments API** for exactly this — files are encrypted client-side before upload and sync across all devices via the existing vault sync mechanism. Implementing attachments using the standard API means Prizm users get full cross-device sync with zero additional server infrastructure, and Vaultwarden users get it entirely free.

## What Changes

- Add support for file attachments on any vault item using the Bitwarden Attachments API
- Implement two-layer client-side encryption: a per-attachment key encrypted by the cipher key, which in turn encrypts the file data (AES-256-CBC + HMAC-SHA256, matching the Bitwarden security whitepaper)
- Display attachments in the vault item detail pane with file name and size
- Allow users to upload, download (open or save to disk), and delete attachments on any existing vault item
- Attachments sync automatically as part of the existing vault sync flow

## Capabilities

### New Capabilities

- `attachment-crypto`: Per-attachment key generation and two-layer encrypt/decrypt — `attachmentKey` encrypts file data; cipher key encrypts `attachmentKey`. Extends `BitwardenCryptoService`.

- `attachment-api`: Network layer for the Bitwarden Attachments API — upload (POST cipher attachment → signed URL → PUT encrypted blob), download (GET signed URL → decrypt), delete (DELETE). Backed by `URLSession`.

- `attachment-vault-item`: Domain entity (`Attachment`) and `AttachmentRepository` protocol. `VaultItem` cipher type gains an `attachments: [Attachment]` field populated from sync.

- `attachment-add-flow`: UI flow for attaching a file to an existing vault item — `NSOpenPanel`, progress indicator, error handling.

- `attachment-view-flow`: UI in the detail pane listing a cipher's attachments with Open and Save to Disk actions, plus delete.

### Modified Capabilities

- `vault-browser-ui`: Detail pane gains an Attachments section below existing field cards when a cipher has one or more attachments, or when the user adds one.

## Impact

- **Domain layer**: New `Attachment` entity; `CipherDetail` (or equivalent) gains `attachments: [Attachment]`; new `AttachmentRepository` protocol
- **Data layer**: `AttachmentRepositoryImpl` — new upload/download/delete network calls; `PrizmCryptoService` extended with two-layer attachment crypto; `AttachmentMapper` for sync payload → `Attachment`; `VaultKeyCache` + `VaultKeyServiceImpl` for cipher key resolution
- **Presentation layer**: Attachments section in detail view; `AttachmentAddViewModel` + `AttachmentRowView`; file picker and progress UI
- **No breaking changes** to existing vault item types, stored data, or sync behaviour
- **Bitwarden cloud users** require a premium account to use attachments; Vaultwarden users have no such restriction
