import Combine
import SwiftUI

/// ViewModel for the password generator popover.
/// Owns the config, generated value, and clipboard logic.
/// Instantiated as `@StateObject` inside `EditFieldRow` so plaintext
/// is released when the popover closes (design D7, Constitution §III).
@MainActor
final class PasswordGeneratorViewModel: ObservableObject {

    // MARK: - Published config properties

    @Published var mode: PasswordGeneratorConfig.Mode = .password { didSet { generate() } }
    @Published var length: Int = 16 { didSet { generate() } }
    @Published var includeUppercase: Bool = true { didSet { generate() } }
    @Published var includeLowercase: Bool = true { didSet { generate() } }
    @Published var includeDigits: Bool = true { didSet { generate() } }
    @Published var includeSymbols: Bool = true { didSet { generate() } }
    @Published var avoidAmbiguous: Bool = false { didSet { generate() } }
    @Published var wordCount: Int = 6 { didSet { generate() } }
    @Published var separator: String = "-" { didSet { generate() } }
    @Published var capitalize: Bool = false { didSet { generate() } }
    @Published var includeNumber: Bool = false { didSet { generate() } }

    // MARK: - Output

    @Published private(set) var generatedValue: String = ""
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let provider: RandomnessProvider
    private let generator = PasswordGenerator()
    private let defaults: UserDefaults
    private var clipboardClearTask: Task<Void, Never>?
    private var isInitializing = true

    // MARK: - Init

    init(provider: RandomnessProvider, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        let config = PasswordGeneratorConfig.load(from: defaults)
        self.mode = config.mode
        self.length = config.length
        self.includeUppercase = config.includeUppercase
        self.includeLowercase = config.includeLowercase
        self.includeDigits = config.includeDigits
        self.includeSymbols = config.includeSymbols
        self.avoidAmbiguous = config.avoidAmbiguous
        self.wordCount = config.wordCount
        self.separator = config.separator
        self.capitalize = config.capitalize
        self.includeNumber = config.includeNumber
        isInitializing = false
        generate()
    }

    deinit {
        clipboardClearTask?.cancel()
    }

    // MARK: - Actions

    func generate() {
        guard !isInitializing else { return }
        do {
            let config = currentConfig()
            switch mode {
            case .password:
                generatedValue = try generator.generatePassword(config: config, provider: provider)
            case .passphrase:
                generatedValue = try generator.generatePassphrase(config: config, provider: provider)
            }
            errorMessage = nil
            config.save(to: defaults)
        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
            generatedValue = ""
        }
    }

    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedValue, forType: .string)

        clipboardClearTask?.cancel()
        clipboardClearTask = Task {
            do {
                try await Task.sleep(for: .seconds(30))
                if pasteboard.string(forType: .string) == generatedValue {
                    pasteboard.clearContents()
                }
            } catch {
                // Task cancelled — do nothing.
            }
        }
    }

    // MARK: - Private

    private func currentConfig() -> PasswordGeneratorConfig {
        var config = PasswordGeneratorConfig()
        config.mode = mode
        config.length = length
        config.includeUppercase = includeUppercase
        config.includeLowercase = includeLowercase
        config.includeDigits = includeDigits
        config.includeSymbols = includeSymbols
        config.avoidAmbiguous = avoidAmbiguous
        config.wordCount = wordCount
        config.separator = separator
        config.capitalize = capitalize
        config.includeNumber = includeNumber
        return config
    }
}
