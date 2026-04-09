import Foundation

/// A decrypted folder. Produced by `PrizmCryptoService.decryptFolders` from `[RawFolder]`.
/// Value type — safe to pass across layers without defensive copying.
nonisolated struct Folder: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
}
