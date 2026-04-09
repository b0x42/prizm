import Foundation

/// Moves one or more items to a folder (or removes from folder if nil).
protocol MoveItemToFolderUseCase {
    func execute(itemId: String, folderId: String?) async throws
    func execute(itemIds: [String], folderId: String?) async throws
}
