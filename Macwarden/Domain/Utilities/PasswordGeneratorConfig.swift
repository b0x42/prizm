import Foundation

/// Configuration for the password/passphrase generator.
/// Persisted to `UserDefaults` as individual keys (UI preference, not vault data).
struct PasswordGeneratorConfig {

    enum Mode: String {
        case password
        case passphrase
    }

    // MARK: - Shared

    var mode: Mode = .password

    // MARK: - Password mode

    var length: Int = 16
    var includeUppercase: Bool = true
    var includeLowercase: Bool = true
    var includeDigits: Bool = true
    var includeSymbols: Bool = true
    var avoidAmbiguous: Bool = false

    // MARK: - Passphrase mode

    var wordCount: Int = 6
    var separator: String = "-"
    var capitalize: Bool = false
    var includeNumber: Bool = false

    // MARK: - UserDefaults persistence

    private enum Key {
        static let mode             = "pwgen.mode"
        static let length           = "pwgen.length"
        static let includeUppercase = "pwgen.includeUppercase"
        static let includeLowercase = "pwgen.includeLowercase"
        static let includeDigits    = "pwgen.includeDigits"
        static let includeSymbols   = "pwgen.includeSymbols"
        static let avoidAmbiguous   = "pwgen.avoidAmbiguous"
        static let wordCount        = "pwgen.wordCount"
        static let separator        = "pwgen.separator"
        static let capitalize       = "pwgen.capitalize"
        static let includeNumber    = "pwgen.includeNumber"
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(length, forKey: Key.length)
        defaults.set(includeUppercase, forKey: Key.includeUppercase)
        defaults.set(includeLowercase, forKey: Key.includeLowercase)
        defaults.set(includeDigits, forKey: Key.includeDigits)
        defaults.set(includeSymbols, forKey: Key.includeSymbols)
        defaults.set(avoidAmbiguous, forKey: Key.avoidAmbiguous)
        defaults.set(wordCount, forKey: Key.wordCount)
        defaults.set(separator, forKey: Key.separator)
        defaults.set(capitalize, forKey: Key.capitalize)
        defaults.set(includeNumber, forKey: Key.includeNumber)
    }

    static func load(from defaults: UserDefaults = .standard) -> PasswordGeneratorConfig {
        var config = PasswordGeneratorConfig()
        if let raw = defaults.string(forKey: Key.mode), let m = Mode(rawValue: raw) {
            config.mode = m
        }
        if defaults.object(forKey: Key.length) != nil {
            config.length = max(5, min(128, defaults.integer(forKey: Key.length)))
        }
        if defaults.object(forKey: Key.includeUppercase) != nil {
            config.includeUppercase = defaults.bool(forKey: Key.includeUppercase)
        }
        if defaults.object(forKey: Key.includeLowercase) != nil {
            config.includeLowercase = defaults.bool(forKey: Key.includeLowercase)
        }
        if defaults.object(forKey: Key.includeDigits) != nil {
            config.includeDigits = defaults.bool(forKey: Key.includeDigits)
        }
        if defaults.object(forKey: Key.includeSymbols) != nil {
            config.includeSymbols = defaults.bool(forKey: Key.includeSymbols)
        }
        if defaults.object(forKey: Key.avoidAmbiguous) != nil {
            config.avoidAmbiguous = defaults.bool(forKey: Key.avoidAmbiguous)
        }
        if defaults.object(forKey: Key.wordCount) != nil {
            config.wordCount = max(3, min(10, defaults.integer(forKey: Key.wordCount)))
        }
        if let sep = defaults.string(forKey: Key.separator) {
            config.separator = sep
        }
        if defaults.object(forKey: Key.capitalize) != nil {
            config.capitalize = defaults.bool(forKey: Key.capitalize)
        }
        if defaults.object(forKey: Key.includeNumber) != nil {
            config.includeNumber = defaults.bool(forKey: Key.includeNumber)
        }
        return config
    }
}
