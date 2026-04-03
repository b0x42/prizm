import Foundation
@testable import Prizm

/// Deterministic `RandomnessProvider` for reproducible tests.
/// Returns bytes from a repeating seed sequence.
final class MockRandomnessProvider: RandomnessProvider, @unchecked Sendable {

    private let seed: [UInt8]
    private var index = 0

    init(seed: [UInt8] = Array(0...255)) {
        self.seed = seed
    }

    func randomBytes(count: Int) throws -> [UInt8] {
        var result = [UInt8]()
        result.reserveCapacity(count)
        for _ in 0..<count {
            result.append(seed[index % seed.count])
            index += 1
        }
        return result
    }
}
