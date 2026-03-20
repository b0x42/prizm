import Foundation

/// Fetches the encrypted vault from the server and populates the in-memory store.
/// Called after login and after every relaunch + unlock.
protocol SyncUseCase {
    func execute(progress: @escaping (String) -> Void) async throws -> SyncResult
}
