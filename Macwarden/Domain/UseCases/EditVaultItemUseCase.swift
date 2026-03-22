import Foundation

/// Persists an edited vault item by re-encrypting and sending it to the Bitwarden API.
///
/// The use case accepts a `DraftVaultItem` (the mutable edit-flow copy) and returns
/// a server-confirmed `VaultItem` decoded from the API response. Any re-encryption or
/// API error is surfaced as a thrown error for the Presentation layer to display inline.
protocol EditVaultItemUseCase {
    /// Re-encrypts `draft`, calls `PUT /ciphers/{id}`, and returns the server-confirmed item.
    ///
    /// - Parameter draft: The mutable draft containing the user's edits.
    /// - Returns: The `VaultItem` decoded from the server response (authoritative post-save state).
    /// - Throws: A typed error describing the failure (crypto, network, or server error).
    func execute(draft: DraftVaultItem) async throws -> VaultItem
}
