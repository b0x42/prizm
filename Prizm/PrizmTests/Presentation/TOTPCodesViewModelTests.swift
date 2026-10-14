import XCTest
@testable import Prizm

/// Test double: deterministic use case driven by a seed -> result table.
private final class StubGenerateTOTPCode: GenerateTOTPCodeUseCase, @unchecked Sendable {
    var callCount = 0
    var failingSeeds: Set<String> = []

    func execute(seed: String, at date: Date) async throws -> TOTPCode {
        callCount += 1
        if failingSeeds.contains(seed) { throw TOTPError.invalidSecret }
        let period = 30
        let t = Int(date.timeIntervalSince1970)
        // Digits encode the current period counter so tests can see rotation.
        let counter = t / period
        return TOTPCode(digits: String(format: "%06d", counter % 1_000_000),
                        period: period,
                        secondsRemaining: period - (t % period))
    }
}

/// Mutable clock shared with the view model under test.
@MainActor
private final class TestClock {
    var now = Date(timeIntervalSince1970: 3_000) // counter 100, 0 s into the period
}

@MainActor
final class TOTPCodesViewModelTests: XCTestCase {

    private var clock = TestClock()
    private var useCase: StubGenerateTOTPCode!
    private var sut: TOTPCodesViewModel!

    override func setUp() {
        super.setUp()
        clock = TestClock()
        useCase = StubGenerateTOTPCode()
        let box = clock
        sut = TOTPCodesViewModel(generate: useCase, now: { box.now })
    }

    override func tearDown() {
        sut.stop()
        super.tearDown()
    }

    private func login(id: String, totp: String?) -> VaultItem {
        VaultItem(
            id: id, name: id, isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .login(LoginContent(username: nil, password: nil, uris: [], totp: totp, notes: nil, customFields: []))
        )
    }

    func test_refresh_publishesCodeForUsableAndUnavailableForUnusable() async {
        useCase.failingSeeds = ["bad"]
        await sut.refreshNow(items: [login(id: "a", totp: "good"), login(id: "b", totp: "bad")])
        XCTAssertEqual(sut.states["a"], .code(TOTPCode(digits: "000100", period: 30, secondsRemaining: 30)))
        XCTAssertEqual(sut.states["b"], .unavailable)
    }

    func test_refresh_skipsItemsWithoutSeed() async {
        await sut.refreshNow(items: [login(id: "a", totp: nil), login(id: "b", totp: "  ")])
        XCTAssertNil(sut.states["a"])
        XCTAssertNil(sut.states["b"])
    }

    func test_refresh_atPeriodBoundary_publishesNewCode() async {
        let items = [login(id: "a", totp: "good")]
        clock.now = Date(timeIntervalSince1970: 3_029) // last second of counter 100
        await sut.refreshNow(items: items)
        XCTAssertEqual(sut.states["a"], .code(TOTPCode(digits: "000100", period: 30, secondsRemaining: 1)))
        clock.now = Date(timeIntervalSince1970: 3_030) // boundary -> counter 101
        await sut.refreshNow(items: items)
        XCTAssertEqual(sut.states["a"], .code(TOTPCode(digits: "000101", period: 30, secondsRemaining: 30)))
    }

    func test_stop_clearsStates_andHaltsUseCaseCalls() async {
        await sut.refreshNow(items: [login(id: "a", totp: "good")])
        XCTAssertFalse(sut.states.isEmpty)
        sut.stop()
        XCTAssertTrue(sut.states.isEmpty)
        let calls = useCase.callCount
        await sut.refreshNow(items: [login(id: "a", totp: "good")]) // ignored while stopped
        XCTAssertEqual(useCase.callCount, calls)
        XCTAssertTrue(sut.states.isEmpty)
    }

    func test_startAfterStop_showsCurrentNotStaleCodes() async {
        let items = [login(id: "a", totp: "good")]
        sut.start(items: items)
        await sut.waitForFirstPass()
        XCTAssertEqual(sut.states["a"], .code(TOTPCode(digits: "000100", period: 30, secondsRemaining: 30)))
        sut.stop()
        clock.now = Date(timeIntervalSince1970: 3_095) // counter 103
        sut.start(items: items)
        await sut.waitForFirstPass()
        XCTAssertEqual(sut.states["a"], .code(TOTPCode(digits: "000103", period: 30, secondsRemaining: 25)))
    }

    func test_copyValue_returnsCodeWithoutSpaces_orNil() async {
        useCase.failingSeeds = ["bad"]
        await sut.refreshNow(items: [login(id: "a", totp: "good"), login(id: "b", totp: "bad")])
        XCTAssertEqual(sut.copyValue(for: "a"), "000100")
        XCTAssertNil(sut.copyValue(for: "b"))
        XCTAssertNil(sut.copyValue(for: "missing"))
    }

    /// Plan goal (T050): one refresh pass for 100 seeds takes under 50 ms, using the real
    /// use case and CryptoKit HMAC rather than the stub.
    func test_refreshPass_for100Seeds_isUnder50ms() async {
        let real = GenerateTOTPCodeUseCaseImpl(crypto: PrizmCryptoServiceImpl())
        let box = clock
        let tracker = TOTPCodesViewModel(generate: real, now: { box.now })
        let seed = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
        let items = (0..<100).map { login(id: "item-\($0)", totp: seed) }

        await tracker.refreshNow(items: items) // warm up
        let start = ContinuousClock.now
        await tracker.refreshNow(items: items)
        let elapsed = ContinuousClock.now - start

        XCTAssertEqual(tracker.states.count, 100)
        XCTAssertLessThan(elapsed, .milliseconds(50), "One pass took \(elapsed)")
        tracker.stop()
    }
}
