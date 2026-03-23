import Foundation
import os.log

/// Concrete implementation of `EditVaultItemUseCase`.
///
/// Delegates re-encryption and network I/O entirely to `VaultRepository.update`, which
/// owns the re-encryption boundary. This use case is intentionally thin — it exists to
/// provide the Domain-layer abstraction that `ItemEditViewModel` depends on, and to give
/// the protocol a testable seam.
final class EditVaultItemUseCaseImpl: EditVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    /// Re-encrypts the draft, persists it via the API, and returns the server-confirmed item.
    func execute(draft: DraftVaultItem) async throws -> VaultItem {
        try await repository.update(draft)
    }
}
