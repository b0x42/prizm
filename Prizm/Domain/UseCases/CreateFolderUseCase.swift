import Foundation

/// Creates a new folder in the vault.
protocol CreateFolderUseCase {
    func execute(name: String) async throws -> Folder
}
