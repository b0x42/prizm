import AppKit
import XCTest
@testable import Prizm

/// "Copy Code" (⌃⌘C) copies the generated code, never the stored seed (FR-016, FR-017).
@MainActor
final class RootViewModelCopyCodeTests: XCTestCase {

    private struct FixedGenerator: GenerateTOTPCodeUseCase {
        func execute(seed: String, at date: Date) async throws -> TOTPCode {
            TOTPCode(digits: "123456", period: 30, secondsRemaining: 12)
        }
    }

    private let validSeed = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    private var sut: RootViewModel!
    private var savedPasteboard: String?

    override func setUp() async throws {
        try await super.setUp()
        savedPasteboard = NSPasteboard.general.string(forType: .string)
        let deps = MockRootDependencies(auth: MockAuthRepository(), vault: MockVaultRepository())
        deps.generateTOTPCode = FixedGenerator()
        sut = RootViewModel(container: deps)
    }

    override func tearDown() async throws {
        NSPasteboard.general.clearContents()
        if let savedPasteboard { NSPasteboard.general.setString(savedPasteboard, forType: .string) }
        try await super.tearDown()
    }

    private func select(totp: String?, username: String? = "alice") async throws {
        let item = VaultItem(
            id: "i1", name: "Acme", isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .login(LoginContent(username: username, password: "pw", uris: [], totp: totp, notes: nil, customFields: []))
        )
        sut.vaultBrowserVM.itemSelection = item
        let deadline = ContinuousClock.now + .milliseconds(500)
        while sut.selectedLogin?.totp != totp, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func waitForPasteboard(_ expected: String) async throws {
        let deadline = ContinuousClock.now + .milliseconds(500)
        while NSPasteboard.general.string(forType: .string) != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    func test_copyCode_copiesGeneratedCodeWithoutSpace_notTheSeed() async throws {
        try await select(totp: validSeed)
        sut.copySelectedField(.totp)
        try await waitForPasteboard("123456")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "123456")
        XCTAssertNotEqual(NSPasteboard.general.string(forType: .string), validSeed)
    }

    func test_codeAvailable_onlyWhenSeedParses() async throws {
        try await select(totp: validSeed)
        XCTAssertTrue(sut.selectedFieldAvailable(.totp))

        try await select(totp: "not-a-seed!")
        XCTAssertFalse(sut.selectedFieldAvailable(.totp))

        try await select(totp: "steam://\(validSeed)")
        XCTAssertFalse(sut.selectedFieldAvailable(.totp))
    }

    func test_codeUnavailable_withNoSeedOrNoSelection() async throws {
        XCTAssertFalse(sut.selectedFieldAvailable(.totp))
        try await select(totp: nil)
        XCTAssertFalse(sut.selectedFieldAvailable(.totp))
        try await select(totp: "   ")
        XCTAssertFalse(sut.selectedFieldAvailable(.totp))
    }

    func test_unusableSeed_copiesNothing() async throws {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("sentinel", forType: .string)
        try await select(totp: "not-a-seed!")
        sut.copySelectedField(.totp)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "sentinel")
    }

    func test_otherFields_stillCopyTheirOwnValues() async throws {
        try await select(totp: validSeed, username: "alice")
        sut.copySelectedField(.username)
        try await waitForPasteboard("alice")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "alice")
    }
}
