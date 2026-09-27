import Foundation

/// Concrete implementation of `CreateVaultItemUseCase`.
/// Delegates encryption and network I/O to `VaultRepository.create`.
final class CreateVaultItemUseCaseImpl: CreateVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    func execute(draft: DraftVaultItem) async throws -> VaultItem {
        try await repository.create(draft)
    }
}

/// Orchestrates item moves and duplication without exposing crypto or attachment keys
/// outside the Data layer.
///
/// Cross-owner moves cannot be represented by Bitwarden as a direct ownership update.
/// They are therefore implemented as create → copy every attachment → soft-delete source.
/// The source is never deleted unless every preceding step succeeds.
final class VaultItemTransferUseCaseImpl: MoveVaultItemUseCase, DuplicateVaultItemUseCase {

    private let repository: any VaultRepository
    private let downloadAttachment: any DownloadAttachmentUseCase
    private let uploadAttachment: any UploadAttachmentUseCase

    init(
        repository: any VaultRepository,
        downloadAttachment: any DownloadAttachmentUseCase,
        uploadAttachment: any UploadAttachmentUseCase
    ) {
        self.repository = repository
        self.downloadAttachment = downloadAttachment
        self.uploadAttachment = uploadAttachment
    }

    func execute(
        item: VaultItem,
        name: String,
        destination: VaultItemDestination,
        includeAttachments: Bool
    ) async throws -> VaultItem {
        try await duplicate(
            item: item,
            name: name,
            destination: destination,
            includeAttachments: includeAttachments
        )
    }

    func execute(
        items: [VaultItem],
        destination: VaultItemDestination,
        includeAttachments: Bool,
        progress: @escaping @MainActor @Sendable (Int) -> Void
    ) async -> VaultItemBulkTransferResult {
        var succeeded: [VaultItem] = []
        var failures: [VaultItemTransferFailure] = []

        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            do {
                let copy = try await duplicate(
                    item: item,
                    name: item.name,
                    destination: destination,
                    includeAttachments: includeAttachments
                )
                succeeded.append(copy)
            } catch {
                failures.append(VaultItemTransferFailure(
                    id: item.id,
                    itemName: item.name,
                    message: error.localizedDescription
                ))
            }
            await progress(index + 1)
        }
        return VaultItemBulkTransferResult(succeeded: succeeded, failures: failures)
    }

    func execute(item: VaultItem, destination: VaultItemDestination) async throws -> VaultItem {
        if item.organizationId == nil, case .personal(let folderId) = destination {
            try await repository.moveItemToFolder(itemId: item.id, folderId: folderId)
            guard let moved = try await repository.allItems().first(where: { $0.id == item.id }) else {
                throw VaultError.itemNotFound(item.id)
            }
            return moved
        }

        if let currentOrganizationId = item.organizationId,
           case .organization(let destinationOrganizationId, let collectionId) = destination,
           currentOrganizationId == destinationOrganizationId {
            var draft = DraftVaultItem(item)
            draft.folderId = nil
            draft.collectionIds = collectionId.map { [$0] } ?? []
            return try await repository.update(draft)
        }

        let copied = try await duplicate(
            item: item,
            name: item.name,
            destination: destination,
            includeAttachments: true
        )
        if Task.isCancelled {
            try? await repository.deleteItem(id: copied.id)
            throw CancellationError()
        }
        do {
            try await repository.deleteItem(id: item.id)
        } catch {
            throw VaultItemTransferError.copySucceededOriginalNotDeleted
        }
        return copied
    }

    func execute(
        items: [VaultItem],
        destination: VaultItemDestination,
        progress: @escaping @MainActor @Sendable (Int) -> Void
    ) async -> VaultItemBulkTransferResult {
        var succeeded: [VaultItem] = []
        var failures: [VaultItemTransferFailure] = []

        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            do {
                succeeded.append(try await execute(item: item, destination: destination))
            } catch {
                failures.append(VaultItemTransferFailure(
                    id: item.id,
                    itemName: item.name,
                    message: error.localizedDescription
                ))
            }
            await progress(index + 1)
        }
        return VaultItemBulkTransferResult(succeeded: succeeded, failures: failures)
    }

    private func duplicate(
        item: VaultItem,
        name: String,
        destination: VaultItemDestination,
        includeAttachments: Bool
    ) async throws -> VaultItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw VaultItemTransferError.copyFailed("A name is required.")
        }

        let draft = DraftVaultItem.duplicate(
            of: item,
            name: trimmedName,
            destination: destination
        )
        let created: VaultItem
        do {
            created = try await repository.create(draft)
        } catch {
            throw VaultItemTransferError.copyFailed(error.localizedDescription)
        }

        guard includeAttachments, !item.attachments.isEmpty else { return created }

        do {
            for attachment in item.attachments {
                try Task.checkCancellation()
                try await copyAttachment(
                    attachment,
                    sourceCipherId: item.id,
                    destinationCipherId: created.id
                )
            }
            return try await repository.allItems().first(where: { $0.id == created.id }) ?? created
        } catch is CancellationError {
            try? await repository.deleteItem(id: created.id)
            throw CancellationError()
        } catch {
            let originalError = error.localizedDescription
            do {
                try await repository.deleteItem(id: created.id)
            } catch {
                throw VaultItemTransferError.copyFailed(
                    "\(originalError) A partial copy may remain in the vault."
                )
            }
            throw VaultItemTransferError.copyFailed(originalError)
        }
    }

    /// Plaintext attachment bytes exist only for this single download/upload pair and are
    /// zeroed before the next attachment starts.
    private func copyAttachment(
        _ attachment: Attachment,
        sourceCipherId: String,
        destinationCipherId: String
    ) async throws {
        var plaintext = try await downloadAttachment.execute(
            cipherId: sourceCipherId,
            attachment: attachment
        )
        defer { plaintext.resetBytes(in: 0..<plaintext.count) }
        _ = try await uploadAttachment.execute(
            cipherId: destinationCipherId,
            fileName: attachment.fileName,
            data: plaintext
        )
    }
}
