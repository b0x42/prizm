import Foundation

final class CreateFolderUseCaseImpl: CreateFolderUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(name: String) async throws -> Folder {
        try await repository.createFolder(name: name)
    }

    // macOS 15: avoid the isolated-deinit crash (swiftlang/swift#88036).
    nonisolated deinit {}
}
