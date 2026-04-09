import Foundation

/// Deletes a folder. Items in the folder become unfoldered.
protocol DeleteFolderUseCase {
    func execute(id: String) async throws
}
