import XCTest
import Combine
@testable import Prizm

@MainActor
final class UnlockViewModelBiometricTests: XCTestCase {

    private var sut:          UnlockViewModel!
    private var mockAuth:     MockAuthRepository!
    private var mockSync:     MockSyncUseCase!
    private var cancellables: Set<AnyCancellable> = []

    private let stubAccount = Account(
        userId:            "user-001",
        email:             "alice@example.com",
        name:              nil,
        serverEnvironment: ServerEnvironment(
            base:      URL(string: "https://vault.example.com")!,
            overrides: nil
        )
    )

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        mockSync = MockSyncUseCase()
        sut      = UnlockViewModel(auth: mockAuth, sync: mockSync, account: stubAccount)
        UserDefaults.standard.removeObject(forKey: "biometricUnlockEnabled")
        UserDefaults.standard.removeObject(forKey: "biometricEnrollmentPromptShown")
    }

    override func tearDown() async throws {
        cancellables.removeAll()
        UserDefaults.standard.removeObject(forKey: "biometricUnlockEnabled")
        UserDefaults.standard.removeObject(forKey: "biometricEnrollmentPromptShown")
        try await super.tearDown()
    }

    // MARK: - biometricUnlockAvailable

    func testBiometricUnlockAvailable_reflectsAuthRepository() {
        mockAuth.stubbedBiometricUnlockAvailable = true
        XCTAssertTrue(sut.biometricUnlockAvailable)
        mockAuth.stubbedBiometricUnlockAvailable = false
        XCTAssertFalse(sut.biometricUnlockAvailable)
    }

    // MARK: - unlockWithBiometrics: success

    func testUnlockWithBiometrics_success_callsAuth() {
        mockAuth.stubbedBiometricUnlockAvailable = true
        sut.unlockWithBiometrics()
        // The internal Task is scheduled on @MainActor. We can't easily await it
        // from a synchronous test. Verify the method was called by checking the
        // mock after the run loop processes the Task.
        let exp = expectation(description: "task runs")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(mockAuth.unlockWithBiometricsCalled)
    }

    // MARK: - unlockWithBiometrics: cancellation

    func testUnlockWithBiometrics_cancellation_noErrorShown() async {
        let cancelError = NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(errSecUserCanceled),
            userInfo: nil
        )
        mockAuth.unlockWithBiometricsError = cancelError

        let exp = expectation(description: "flow returns to unlock")
        sut.$flowState
            .filter { $0 == .unlock }
            .dropFirst() // skip initial .unlock
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.unlockWithBiometrics()
        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - unlockWithBiometrics: invalidation

    func testUnlockWithBiometrics_invalidated_showsErrorMessage() async {
        mockAuth.unlockWithBiometricsError = AuthError.biometricInvalidated

        let exp = expectation(description: "error message shown")
        sut.$errorMessage
            .compactMap { $0 }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.unlockWithBiometrics()
        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - triggerBiometricUnlockIfAvailable

    func testTriggerBiometricUnlock_notAvailable_noOp() async {
        mockAuth.stubbedBiometricUnlockAvailable = false
        sut.triggerBiometricUnlockIfAvailable()
        // No call should have been made.
        XCTAssertFalse(mockAuth.unlockWithBiometricsCalled)
    }

    func testTriggerBiometricUnlock_available_callsUnlock() {
        mockAuth.stubbedBiometricUnlockAvailable = true
        sut.triggerBiometricUnlockIfAvailable()
        let exp = expectation(description: "task runs")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(mockAuth.unlockWithBiometricsCalled)
    }

    // MARK: - Enrollment prompt

    func testDismissEnrollmentPrompt_callsPerformSync() async {
        sut.showEnrollmentPrompt = true
        let exp = expectation(description: "transitions to vault after dismiss")
        sut.$flowState
            .filter { $0 == .vault }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.dismissEnrollmentPrompt()
        await fulfillment(of: [exp], timeout: 3.0)
        XCTAssertFalse(sut.showEnrollmentPrompt)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "biometricEnrollmentPromptShown"))
    }
}
