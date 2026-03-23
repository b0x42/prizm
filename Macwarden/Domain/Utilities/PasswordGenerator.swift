import Foundation

/// Pure-Swift password and passphrase generator.
/// Receives randomness via `RandomnessProvider` injection — no Security.framework dependency.
struct PasswordGenerator {

    // MARK: - Character sets

    private static let uppercaseChars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let lowercaseChars = Array("abcdefghijklmnopqrstuvwxyz")
    private static let digitChars     = Array("0123456789")
    private static let symbolChars    = Array("!@#$%^&*()_+-=[]{}|;':\",.< >?/")
    private static let ambiguousChars: Set<Character> = ["0", "O", "I", "l", "1", "|"]

    // MARK: - EFF word list (loaded once, cached)

    static let effWordList: [String] = {
        guard let url = Bundle.main.url(forResource: "eff-large-wordlist", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }()

    // MARK: - Password generation

    /// Generates a random character-based password.
    /// - Throws: If the randomness provider fails.
    func generatePassword(config: PasswordGeneratorConfig, provider: RandomnessProvider) throws -> String {
        let length = max(5, min(128, config.length))

        // Build enabled character sets.
        var sets: [[Character]] = []
        if config.includeUppercase { sets.append(Self.uppercaseChars) }
        if config.includeLowercase { sets.append(Self.lowercaseChars) }
        if config.includeDigits    { sets.append(Self.digitChars) }
        if config.includeSymbols   { sets.append(Self.symbolChars) }

        // Guard: at least one set must be enabled.
        if sets.isEmpty {
            sets.append(Self.lowercaseChars)
        }

        // Filter ambiguous characters if requested.
        if config.avoidAmbiguous {
            sets = sets.map { $0.filter { !Self.ambiguousChars.contains($0) } }
            // Remove any sets that became empty after filtering.
            sets = sets.filter { !$0.isEmpty }
            if sets.isEmpty {
                sets.append(Self.lowercaseChars.filter { !Self.ambiguousChars.contains($0) })
            }
        }

        let pool = sets.flatMap { $0 }

        // Note: `byte % count` introduces slight modulo bias when count doesn't evenly
        // divide 256 (max ~0.4% for typical pool sizes). Acceptable for password generation;
        // matches Bitwarden's own approach.

        // 1. Pick one random character from each enabled set (guarantee).
        var result: [Character] = []
        for set in sets {
            let byte = try provider.randomBytes(count: 1)[0]
            let index = Int(byte) % set.count
            result.append(set[index])
        }

        // 2. Fill remaining slots from the full pool.
        let remaining = length - result.count
        if remaining > 0 {
            let bytes = try provider.randomBytes(count: remaining)
            for byte in bytes {
                let index = Int(byte) % pool.count
                result.append(pool[index])
            }
        }

        // 3. Fisher-Yates shuffle using provider bytes.
        let shuffleBytes = try provider.randomBytes(count: result.count)
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = Int(shuffleBytes[i]) % (i + 1)
            result.swapAt(i, j)
        }

        return String(result)
    }

    // MARK: - Passphrase generation

    /// Generates a word-based passphrase from the EFF Large Wordlist.
    /// - Throws: If the randomness provider fails.
    func generatePassphrase(config: PasswordGeneratorConfig, provider: RandomnessProvider) throws -> String {
        let wordCount = max(3, min(10, config.wordCount))
        let wordList = Self.effWordList
        guard !wordList.isEmpty else { return "" }

        // Select random words. Use 2 bytes per word for better distribution over 7776 words.
        let wordBytes = try provider.randomBytes(count: wordCount * 2)
        var words: [String] = []
        for i in 0..<wordCount {
            let value = (Int(wordBytes[i * 2]) << 8) | Int(wordBytes[i * 2 + 1])
            let index = value % wordList.count
            var word = wordList[index]
            if config.capitalize {
                word = word.prefix(1).uppercased() + word.dropFirst()
            }
            words.append(word)
        }

        // Append a random digit to one randomly chosen word if requested.
        if config.includeNumber {
            let extraBytes = try provider.randomBytes(count: 2)
            let wordIndex = Int(extraBytes[0]) % words.count
            let digit = Int(extraBytes[1]) % 10
            words[wordIndex] += String(digit)
        }

        return words.joined(separator: config.separator)
    }
}
