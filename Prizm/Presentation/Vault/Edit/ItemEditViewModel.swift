import Combine
import Foundation
import os.log
import SwiftUI

// MARK: - ItemEditViewModel

/// ViewModel for the item edit sheet. Owns the mutable `DraftVaultItem`, orchestrates
/// the async save call, and coordinates discard confirmation and vault-lock dismissal.
///
/// Lifecycle:
/// 1. Created with an existing `VaultItem` when the edit sheet opens.
/// 2. The view binds to `draft` - changes are reflected immediately in the form.
/// 3. `save()` is called when the user presses Save / ⌘S.
/// 4. On success: `isDismissed` is set to `true`; the caller dismisses the sheet.
/// 5. On dismiss (save or discard): the caller should call `clearDraft()` to satisfy
///    Constitution §III (plaintext minimisation for in-memory secret data).
/// 6. On vault lock: `isDismissed` is set immediately without confirmation.
@MainActor
final class ItemEditViewModel: ObservableObject {

    struct PendingAttachment: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let fileName: String
        let size: Int

        var sizeName: String {
            ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
    }

    // MARK: - Published state

    /// The mutable draft being edited. Bound directly to form fields.
    @Published var draft: DraftVaultItem

    /// `true` while the save request is in-flight. Used to disable Save / ⌘S and
    /// change the Save button label to "Saving…".
    @Published private(set) var isSaving: Bool = false

    /// Non-nil when the save request failed. Shown as an inline error banner.
    @Published private(set) var saveError: String? = nil
    @Published private(set) var attachments: [Attachment] = []
    @Published private(set) var pendingAttachments: [PendingAttachment] = []

    /// Set to `true` to signal the enclosing sheet to dismiss.
    @Published private(set) var isDismissed: Bool = false

    // MARK: - Derived state

    /// `true` when the Name field is non-empty and no save is in-flight.
    var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    /// Non-nil when `draft.name` is blank, triggering inline validation.
    var nameValidationError: String? {
        draft.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required" : nil
    }

    /// `true` when any field differs from the original item captured at open time.
    /// Used to decide whether the discard confirmation prompt is needed.
    var hasChanges: Bool {
        draft != original || !deletedAttachmentIDs.isEmpty || !pendingAttachments.isEmpty
    }

    /// `true` when editing an existing item (as opposed to creating a new one).
    /// Used to conditionally show the Delete button in the edit sheet.
    var isEditing: Bool { editUseCase != nil }

    // MARK: - Private state

    /// Snapshot of the item as it was when the sheet opened - used for `hasChanges`.
    /// `var` so `clearDraft()` can overwrite it with a blank sentinel (Constitution §III).
    private var original: DraftVaultItem

    private let editUseCase: (any EditVaultItemUseCase)?
    private let createUseCase: (any CreateVaultItemUseCase)?
    private let uploadAttachmentUseCase: (any UploadAttachmentUseCase)?
    private let deleteAttachmentUseCase: (any DeleteAttachmentUseCase)?
    private let attachmentFilePicker: (@MainActor () -> [(url: URL, bytes: Int)])?
    private var deletedAttachmentIDs: Set<String> = []
    private var sourceItem: VaultItem?
    private let logger  = Logger(subsystem: "com.prizm", category: "ItemEditViewModel")

    /// Called on save success with the server-confirmed `VaultItem` so the caller
    /// (VaultBrowserViewModel or parent) can refresh the list pane.
    var onSaveSuccess: ((VaultItem) -> Void)?
    var onAttachmentsChanged: (() -> Void)?

    /// Available folders for the folder picker in the edit sheet.
    let folders: [Folder]

    /// Available organizations - used to resolve collection org names.
    let organizations: [Organization]

    /// Collections available for the collection picker (all orgs).
    let collections: [OrgCollection]

    /// Retain token for the vault-lock observer.
    private nonisolated(unsafe) var lockObserver: NSObjectProtocol?

    // MARK: - Init

    /// Edit mode: initialised with an existing item.
    init(
        item: VaultItem,
        useCase: any EditVaultItemUseCase,
        folders: [Folder] = [],
        organizations: [Organization] = [],
        collections: [OrgCollection] = [],
        uploadAttachmentUseCase: (any UploadAttachmentUseCase)? = nil,
        deleteAttachmentUseCase: (any DeleteAttachmentUseCase)? = nil,
        attachmentFilePicker: (@MainActor () -> [(url: URL, bytes: Int)])? = nil
    ) {
        self.draft         = DraftVaultItem(item)
        self.original      = DraftVaultItem(item)
        self.editUseCase   = useCase
        self.createUseCase = nil
        self.uploadAttachmentUseCase = uploadAttachmentUseCase
        self.deleteAttachmentUseCase = deleteAttachmentUseCase
        self.attachmentFilePicker = attachmentFilePicker
        self.attachments = item.attachments
        self.sourceItem = item
        self.folders       = folders
        self.organizations = organizations
        self.collections   = collections
        subscribeToVaultLock()
    }

    /// Create mode: initialised with a blank draft for the given type.
    init(type: ItemType, useCase: any CreateVaultItemUseCase, folders: [Folder] = [],
         folderId: String? = nil, organizationId: String? = nil, collectionIds: [String] = [],
         organizations: [Organization] = [], collections: [OrgCollection] = []) {
        var blank = DraftVaultItem.blank(type: type)
        blank.folderId       = folderId
        blank.organizationId = organizationId
        blank.collectionIds  = collectionIds
        self.draft         = blank
        self.original      = blank
        self.editUseCase   = nil
        self.createUseCase = useCase
        self.uploadAttachmentUseCase = nil
        self.deleteAttachmentUseCase = nil
        self.attachmentFilePicker = nil
        self.sourceItem = nil
        self.folders       = folders
        self.organizations = organizations
        self.collections   = collections
        subscribeToVaultLock()
    }

    // MARK: - Save

    /// Validates, calls the use case, handles success/failure.
    func save() {
        guard canSave else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            isSaving  = true
            saveError = nil
            do {
                let saved: VaultItem
                if let createUseCase {
                    saved = try await createUseCase.execute(draft: draft)
                } else if let editUseCase {
                    if draft != original {
                        saved = try await editUseCase.execute(draft: draft)
                        original = DraftVaultItem(saved)
                        sourceItem = saved
                    } else if let sourceItem {
                        saved = sourceItem
                    } else {
                        preconditionFailure("ItemEditViewModel: missing source item")
                    }
                } else {
                    preconditionFailure("ItemEditViewModel: no use case configured")
                }

                onSaveSuccess?(saved)
                try await applyPendingAttachmentChanges(cipherId: saved.id)
                clearDraft()
                isDismissed = true
                logger.info("Item saved: \(saved.id, privacy: .public)")
            } catch {
                saveError = error.localizedDescription
                logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            }
            isSaving = false
        }
    }

    // MARK: - Deferred attachments

    func selectAttachments() {
        guard let attachmentFilePicker else { return }
        let selections = attachmentFilePicker()
        stageAttachments(selections.map(\.url))
    }

    func stageAttachments(_ urls: [URL]) {
        saveError = nil
        for url in urls {
            guard !pendingAttachments.contains(where: {
                $0.url.standardizedFileURL == url.standardizedFileURL
            }) else { continue }

            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard size <= EditAttachmentLimits.maximumBytes else {
                saveError = "\(url.lastPathComponent) exceeds the 500 MB attachment limit."
                continue
            }
            pendingAttachments.append(PendingAttachment(
                url: url,
                fileName: url.lastPathComponent,
                size: size
            ))
        }
    }

    func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
        deletedAttachmentIDs.insert(attachment.id)
    }

    func removePendingAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    private func applyPendingAttachmentChanges(cipherId: String) async throws {
        if !deletedAttachmentIDs.isEmpty {
            guard let deleteAttachmentUseCase else {
                throw EditAttachmentError.operationUnavailable
            }
            for attachmentId in Array(deletedAttachmentIDs) {
                try await deleteAttachmentUseCase.execute(
                    cipherId: cipherId,
                    attachmentId: attachmentId
                )
                deletedAttachmentIDs.remove(attachmentId)
                onAttachmentsChanged?()
            }
        }

        if !pendingAttachments.isEmpty {
            guard let uploadAttachmentUseCase else {
                throw EditAttachmentError.operationUnavailable
            }
            for pending in Array(pendingAttachments) {
                var data = try Data(contentsOf: pending.url)
                do {
                    _ = try await uploadAttachmentUseCase.execute(
                        cipherId: cipherId,
                        fileName: pending.fileName,
                        data: data
                    )
                    data.resetBytes(in: 0..<data.count)
                    pendingAttachments.removeAll { $0.id == pending.id }
                    onAttachmentsChanged?()
                } catch {
                    data.resetBytes(in: 0..<data.count)
                    throw error
                }
            }
        }
    }

    // MARK: - Discard

    /// Discards changes and signals the sheet to dismiss. Call only after confirming
    /// with the user when `hasChanges == true`.
    func discard() {
        clearDraft()
        isDismissed = true
    }

    // MARK: - Memory cleanup (Constitution §III)

    /// Clears the draft's plaintext field values from memory.
    ///
    /// Called on both the save path (after receiving the server response) and the discard
    /// path. Reduces the window during which plaintext passwords and other secrets are
    /// held in the heap. Swift ARC may retain additional copies; this removes the primary
    /// reference held by this ViewModel.
    func clearDraft() {
        // Replace both draft and original with a blank sentinel to release all
        // string values (passwords, keys, notes) from the heap (Constitution §III).
        // `original` must also be cleared - it holds a full snapshot of the item
        // as it was when the sheet opened, including any sensitive plaintext fields.
        let blank = DraftVaultItem(VaultItem(
            id: original.id,
            name: "",
            isFavorite: false,
            isDeleted: false,
            creationDate: original.creationDate,
            revisionDate: original.revisionDate,
            content: .secureNote(SecureNoteContent(notes: nil, customFields: []))
        ))
        draft    = blank
        original = blank
        attachments.removeAll()
        pendingAttachments.removeAll()
        deletedAttachmentIDs.removeAll()
        sourceItem = nil
    }

    // MARK: - Vault lock observation

    private func subscribeToVaultLock() {
        lockObserver = NotificationCenter.default.addObserver(
            forName: .vaultDidLock,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Dismiss immediately - no confirmation prompt (spec §8.10).
                self?.clearDraft()
                self?.isDismissed = true
            }
        }
    }

    deinit {
        if let obs = lockObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

private enum EditAttachmentLimits {
    static let maximumBytes = 500 * 1024 * 1024
}

private enum EditAttachmentError: LocalizedError {
    case operationUnavailable

    var errorDescription: String? {
        "Attachment changes are unavailable."
    }
}
