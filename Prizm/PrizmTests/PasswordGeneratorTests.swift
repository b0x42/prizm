import XCTest
@testable import Prizm

@MainActor
final class PasswordGeneratorTests: XCTestCase {

    private var generator: PasswordGenerator!
    private var provider: MockRandomnessProvider!

    override func setUp() async throws {
        try await super.setUp()
        generator = PasswordGenerator()
        provider = MockRandomnessProvider()
    }

    // MARK: - 1.5 Random password mode

    func testPasswordLength_minimum5() async throws {
        var config = PasswordGeneratorConfig()
        config.length = 5
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertEqual(result.count, 5)
    }

    func testPasswordLength_maximum128() async throws {
        var config = PasswordGeneratorConfig()
        config.length = 128
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertEqual(result.count, 128)
    }

    func testPasswordLength_clampedBelow5() async throws {
        var config = PasswordGeneratorConfig()
        config.length = 2
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertEqual(result.count, 5)
    }

    func testPasswordLength_clampedAbove128() async throws {
        var config = PasswordGeneratorConfig()
        config.length = 200
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertEqual(result.count, 128)
    }

    func testPassword_uppercaseOnly() async throws {
        var config = PasswordGeneratorConfig()
        config.includeUppercase = true
        config.includeLowercase = false
        config.includeDigits = false
        config.includeSymbols = false
        config.length = 20
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertTrue(result.allSatisfy { $0.isUppercase })
    }

    func testPassword_allSetsPool_containsAllTypes() async throws {
        var config = PasswordGeneratorConfig()
        config.length = 128
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertTrue(result.contains(where: { $0.isUppercase }))
        XCTAssertTrue(result.contains(where: { $0.isLowercase }))
        XCTAssertTrue(result.contains(where: { $0.isNumber }))
        XCTAssertTrue(result.contains(where: { !$0.isLetter && !$0.isNumber }))
    }

    func testPassword_atLeastOnePerSet_guarantee() async throws {
        // With all sets enabled and short length, each set must appear at least once.
        var config = PasswordGeneratorConfig()
        config.length = 5
        // Run multiple times with different seeds.
        for seed in [Array<UInt8>(repeating: 0, count: 256),
                     Array<UInt8>(repeating: 127, count: 256),
                     Array<UInt8>(repeating: 255, count: 256)] {
            let p = MockRandomnessProvider(seed: seed)
            let result = try generator.generatePassword(config: config, provider: p)
            XCTAssertTrue(result.contains(where: { $0.isUppercase }), "Missing uppercase in: \(result)")
            XCTAssertTrue(result.contains(where: { $0.isLowercase }), "Missing lowercase in: \(result)")
            XCTAssertTrue(result.contains(where: { $0.isNumber }), "Missing digit in: \(result)")
            XCTAssertTrue(result.contains(where: { !$0.isLetter && !$0.isNumber }), "Missing symbol in: \(result)")
        }
    }

    func testPassword_avoidAmbiguous_excludesChars() async throws {
        let ambiguous: Set<Character> = ["0", "O", "I", "l", "1", "|"]
        var config = PasswordGeneratorConfig()
        config.avoidAmbiguous = true
        config.length = 128
        let result = try generator.generatePassword(config: config, provider: provider)
        for char in result {
            XCTAssertFalse(ambiguous.contains(char), "Found ambiguous char '\(char)' in result")
        }
    }

    func testPassword_noWhitespace_withSymbolsEnabled() async throws {
        var config = PasswordGeneratorConfig()
        config.length = 128
        for seed in [Array<UInt8>(repeating: 0, count: 256),
                     Array<UInt8>(repeating: 127, count: 256),
                     Array<UInt8>(repeating: 255, count: 256),
                     Array<UInt8>(0...255)] {
            let p = MockRandomnessProvider(seed: seed)
            let result = try generator.generatePassword(config: config, provider: p)
            XCTAssertFalse(result.contains(where: { $0.isWhitespace }), "Password contains whitespace: \(result)")
        }
    }

    func testPassword_lastSetLock_preventsEmptyPool() async throws {
        // All sets disabled — generator should fall back to lowercase.
        var config = PasswordGeneratorConfig()
        config.includeUppercase = false
        config.includeLowercase = false
        config.includeDigits = false
        config.includeSymbols = false
        config.length = 10
        let result = try generator.generatePassword(config: config, provider: provider)
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.allSatisfy { $0.isLowercase })
    }

    // MARK: - 1.6 Passphrase mode

    func testPassphrase_wordCountBounds_minimum3() async throws {
        var config = PasswordGeneratorConfig()
        config.wordCount = 3
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        XCTAssertEqual(words.count, 3)
    }

    func testPassphrase_wordCountBounds_maximum10() async throws {
        var config = PasswordGeneratorConfig()
        config.wordCount = 10
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        XCTAssertEqual(words.count, 10)
    }

    func testPassphrase_defaultWordCount_is6() async throws {
        let config = PasswordGeneratorConfig()
        XCTAssertEqual(config.wordCount, 6)
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        XCTAssertEqual(words.count, 6)
    }

    func testPassphrase_separatorInjection() async throws {
        var config = PasswordGeneratorConfig()
        config.separator = "."
        config.wordCount = 3
        let result = try generator.generatePassphrase(config: config, provider: provider)
        XCTAssertTrue(result.contains("."))
        let words = result.components(separatedBy: ".")
        XCTAssertEqual(words.count, 3)
    }

    func testPassphrase_capitalize_uppercasesFirstLetter() async throws {
        var config = PasswordGeneratorConfig()
        config.capitalize = true
        config.wordCount = 4
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        for word in words {
            // Strip trailing digit if include-number appended one.
            let base = word.filter { $0.isLetter }
            if let first = base.first {
                XCTAssertTrue(first.isUppercase, "Word '\(word)' should start uppercase")
            }
        }
    }

    func testPassphrase_includeNumber_appendsDigitToOneWord() async throws {
        var config = PasswordGeneratorConfig()
        config.includeNumber = true
        config.wordCount = 4
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        let wordsWithTrailingDigit = words.filter { word in
            guard let last = word.last else { return false }
            return last.isNumber
        }
        XCTAssertEqual(wordsWithTrailingDigit.count, 1, "Exactly one word should have a trailing digit")
    }

    func testPassphrase_allWordsFromEFFList() async throws {
        let wordList = Set(PasswordGenerator.effWordList)
        // Skip if word list not loaded (test bundle may not include resources).
        guard !wordList.isEmpty else { return }

        var config = PasswordGeneratorConfig()
        config.wordCount = 6
        config.includeNumber = false
        config.capitalize = false
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        for word in words {
            XCTAssertTrue(wordList.contains(word), "Word '\(word)' not in EFF list")
        }
    }

    func testPassphrase_wordCountClamped_below3() async throws {
        var config = PasswordGeneratorConfig()
        config.wordCount = 1
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        XCTAssertEqual(words.count, 3)
    }

    func testPassphrase_wordCountClamped_above10() async throws {
        var config = PasswordGeneratorConfig()
        config.wordCount = 20
        let result = try generator.generatePassphrase(config: config, provider: provider)
        let words = result.components(separatedBy: config.separator)
        XCTAssertEqual(words.count, 10)
    }
}
