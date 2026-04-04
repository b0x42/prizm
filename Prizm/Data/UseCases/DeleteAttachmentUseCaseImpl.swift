import Foundation

/// Concrete implementation of `DeleteAttachmentUseCase`.
///
/// Delete requires no key material — only the cipher ID and attachment ID are sent.
/// `VaultKeyService` is intentionally NOT injected (Constitution §VI — YAGNI).
final class DeleteAttachmentUseCaseImpl: DeleteAttachmentUseCase {

    private let repository: any AttachmentRepository

    init(repository: any AttachmentRepository) {
        self.repository = repository
    }

    func execute(cipherId: String, attachmentId: String) async throws {
        try await repository.delete(cipherId: cipherId, attachmentId: attachmentId)
    }
}
