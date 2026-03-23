import Foundation

/// Abstraction over cryptographic random byte generation.
/// Keeps the Domain layer free of Security.framework.
protocol RandomnessProvider {
    func randomBytes(count: Int) throws -> [UInt8]
}
