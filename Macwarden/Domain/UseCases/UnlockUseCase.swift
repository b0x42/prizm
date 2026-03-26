import Foundation

/// Re-derives the symmetric key from the master password and unlocks the in-memory vault.
/// No network request — purely local KDF. Followed by `SyncUseCase` to re-populate
/// the vault (in-memory store is cleared on app quit).
protocol UnlockUseCase {
    /// - Security goal: `masterPassword` is `Data` so the caller can zero the bytes after
    ///   the KDF call, reducing heap exposure (Constitution §III).
    func execute(masterPassword: Data) async throws -> Account
}
