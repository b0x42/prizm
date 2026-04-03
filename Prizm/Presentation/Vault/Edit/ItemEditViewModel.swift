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
/// 2. The view binds to `draft` — changes are reflected immediately in the form.
/// 3. `save()` is called when the user presses Save / ⌘S.
/// 4. On success: `isDismissed` is set to `true`; the caller dismisses the sheet.
/// 5. On dismiss (save or discard): the caller should call `clearDraft()` to satisfy
///    Constitution §III (plaintext minimisation for in-memory secret data).
/// 6. On vault lock: `isDismissed` is set immediately without confirmation.
@MainActor
final class ItemEditViewModel: ObservableObject {

    // MARK: - Published state

    /// The mutable draft being edited. Bound directly to form fields.
    @Published var draft: DraftVaultItem

    /// `true` while the save request is in-flight. Used to disable Save / ⌘S and
    /// change the Save button label to "Saving…".
    @Published private(set) var isSaving: Bool = false

    /// Non-nil when the save request failed. Shown as an inline error banner.
    @Published private(set) var saveError: String? = nil

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
        draft != original
    }

    // MARK: - Private state

    /// Snapshot of the item as it was when the sheet opened — used for `hasChanges`.
    /// `var` so `clearDraft()` can overwrite it with a blank sentinel (Constitution §III).
    private var original: DraftVaultItem

    private let editUseCase: (any EditVaultItemUseCase)?
    private let createUseCase: (any CreateVaultItemUseCase)?
    private let logger  = Logger(subsystem: "com.prizm", category: "ItemEditViewModel")

    /// Called on save success with the server-confirmed `VaultItem` so the caller
    /// (VaultBrowserViewModel or parent) can refresh the list pane.
    var onSaveSuccess: ((VaultItem) -> Void)?

    /// Retain token for the vault-lock observer.
    private nonisolated(unsafe) var lockObserver: NSObjectProtocol?

    // MARK: - Init

    /// Edit mode: initialised with an existing item.
    init(item: VaultItem, useCase: any EditVaultItemUseCase) {
        self.draft    = DraftVaultItem(item)
        self.original = DraftVaultItem(item)
        self.editUseCase  = useCase
        self.createUseCase = nil
        subscribeToVaultLock()
    }

    /// Create mode: initialised with a blank draft for the given type.
    init(type: ItemType, useCase: any CreateVaultItemUseCase) {
        let blank = DraftVaultItem.blank(type: type)
        self.draft    = blank
        self.original = blank
        self.editUseCase  = nil
        self.createUseCase = useCase
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
                    saved = try await editUseCase.execute(draft: draft)
                } else {
                    preconditionFailure("ItemEditViewModel: no use case configured")
                }
                onSaveSuccess?(saved)
                clearDraft()
                isDismissed = true
                logger.info("Item saved: \(self.draft.id, privacy: .public)")
            } catch {
                saveError = error.localizedDescription
                logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            }
            isSaving = false
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
        // `original` must also be cleared — it holds a full snapshot of the item
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
    }

    // MARK: - Vault lock observation

    private func subscribeToVaultLock() {
        lockObserver = NotificationCenter.default.addObserver(
            forName: .vaultDidLock,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Dismiss immediately — no confirmation prompt (spec §8.10).
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
