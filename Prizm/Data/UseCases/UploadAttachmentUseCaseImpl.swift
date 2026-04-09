import Foundation

/// Concrete implementation of `UploadAttachmentUseCase`.
///
/// Resolves the cipher key internally via `VaultKeyService` so that raw key material
/// never surfaces to the Presentation layer (Constitution §II/§III). Forwards to
/// `AttachmentRepository.upload` which performs all encryption and network I/O.
final class UploadAttachmentUseCaseImpl: UploadAttachmentUseCase {

    private let repository:      any AttachmentRepository
    private let vaultKeyService: any VaultKeyService

    init(repository: any AttachmentRepository, vaultKeyService: any VaultKeyService) {
        self.repository      = repository
        self.vaultKeyService = vaultKeyService
    }

    func execute(cipherId: String, fileName: String, data: Data) async throws -> Attachment {
        let cipherKey = try await vaultKeyService.cipherKey(for: cipherId)
        return try await repository.upload(cipherId: cipherId, fileName: fileName, data: data, cipherKey: cipherKey)
    }
}
