import Foundation

/// Renames an existing folder.
protocol RenameFolderUseCase {
    func execute(id: String, name: String) async throws -> Folder
}
