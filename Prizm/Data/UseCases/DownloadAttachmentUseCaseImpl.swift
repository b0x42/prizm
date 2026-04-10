import Foundation

/// Concrete implementation of `DownloadAttachmentUseCase`.
///
/// Resolves the cipher key internally via `VaultKeyService` so that raw key material
/// never surfaces to the Presentation layer (Constitution §II/§III). Forwards to
/// `AttachmentRepository.download` which fetches, decrypts, and returns the file bytes.
final class DownloadAttachmentUseCaseImpl: DownloadAttachmentUseCase {

    private let repository:      any AttachmentRepository
    private let vaultKeyService: any VaultKeyService

    init(repository: any AttachmentRepository, vaultKeyService: any VaultKeyService) {
        self.repository      = repository
        self.vaultKeyService = vaultKeyService
    }

    func execute(cipherId: String, attachment: Attachment) async throws -> Data {
        let cipherKey = try await vaultKeyService.cipherKey(for: cipherId)
        return try await repository.download(cipherId: cipherId, attachment: attachment, cipherKey: cipherKey)
    }
}
