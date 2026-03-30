import XCTest
@testable import Macwarden

@MainActor
final class PasswordGeneratorViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private var provider: MockRandomnessProvider!

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: "PasswordGeneratorViewModelTests")!
        defaults.removePersistentDomain(forName: "PasswordGeneratorViewModelTests")
        provider = MockRandomnessProvider()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "PasswordGeneratorViewModelTests")
        try await super.tearDown()
    }

    func testInit_generatesValueImmediately() {
        let vm = PasswordGeneratorViewModel(provider: provider, defaults: defaults)
        XCTAssertFalse(vm.generatedValue.isEmpty)
    }

    func testConfigChange_triggersRegeneration() {
        let vm = PasswordGeneratorViewModel(provider: provider, defaults: defaults)
        let first = vm.generatedValue
        vm.length = 32
        // Value should change (different length = different output).
        XCTAssertNotEqual(vm.generatedValue.count, first.count)
    }

    func testModeSwitch_triggersRegeneration() {
        let vm = PasswordGeneratorViewModel(provider: provider, defaults: defaults)
        vm.mode = .passphrase
        XCTAssertTrue(vm.generatedValue.contains("-"))
    }

    func testCopyToClipboard_writesToPasteboard() {
        let vm = PasswordGeneratorViewModel(provider: provider, defaults: defaults)
        vm.copyToClipboard()
        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, vm.generatedValue)
    }

    func testSettingsPersisted_toUserDefaults() {
        let vm = PasswordGeneratorViewModel(provider: provider, defaults: defaults)
        vm.length = 42
        vm.mode = .passphrase

        // Load a new VM from the same defaults — should restore.
        let provider2 = MockRandomnessProvider()
        let vm2 = PasswordGeneratorViewModel(provider: provider2, defaults: defaults)
        XCTAssertEqual(vm2.length, 42)
        XCTAssertEqual(vm2.mode, .passphrase)
    }

    func testDefaultsRestored_onFirstLaunch() {
        let vm = PasswordGeneratorViewModel(provider: provider, defaults: defaults)
        XCTAssertEqual(vm.mode, .password)
        XCTAssertEqual(vm.length, 16)
        XCTAssertEqual(vm.wordCount, 6)
        XCTAssertTrue(vm.includeUppercase)
        XCTAssertTrue(vm.includeLowercase)
        XCTAssertTrue(vm.includeDigits)
        XCTAssertTrue(vm.includeSymbols)
        XCTAssertFalse(vm.avoidAmbiguous)
        XCTAssertEqual(vm.separator, "-")
        XCTAssertFalse(vm.capitalize)
        XCTAssertFalse(vm.includeNumber)
    }
}
