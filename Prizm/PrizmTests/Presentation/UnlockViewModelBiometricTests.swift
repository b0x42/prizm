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

    // MARK: - unlockWithBiometrics: re-arm after cancellation

    func testUnlockWithBiometrics_cancellation_rearmsImmediately() async {
        // Cancellation should re-call triggerBiometricUnlockIfAvailable(), which
        // calls unlockWithBiometrics() again — always-armed behaviour (design Decision 2).
        mockAuth.stubbedBiometricUnlockAvailable = true

        let cancelError = NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(errSecUserCanceled),
            userInfo: nil
        )
        // First call cancels; second call also cancels (avoids infinite loop in test).
        // We just need to confirm the second call is made.
        mockAuth.unlockWithBiometricsError = cancelError

        let exp = expectation(description: "re-arm fires second call")
        // Wait for callCount to reach 2.
        var token: AnyCancellable?
        token = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.mockAuth.unlockWithBiometricsCallCount >= 2 {
                    exp.fulfill()
                    token?.cancel()
                }
            }

        sut.unlockWithBiometrics()
        await fulfillment(of: [exp], timeout: 3.0)
        XCTAssertGreaterThanOrEqual(mockAuth.unlockWithBiometricsCallCount, 2)
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

    // MARK: - Enrollment prompt (inline via flowState)

    func testDismissEnrollmentPrompt_transitionsToVault() async {
        // Drive enrollment state through the real unlock flow:
        // biometrics capable + not enabled + prompt never shown → flowState becomes .enrollmentPrompt
        mockAuth.stubbedDeviceBiometricCapable = true
        UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
        UserDefaults.standard.set(false, forKey: "biometricEnrollmentPromptShown")

        // Await enrollmentPrompt state after password unlock.
        let enrollExp = expectation(description: "reaches enrollmentPrompt state")
        sut.$flowState
            .compactMap { state -> EnrollmentReason? in
                if case .enrollmentPrompt(let reason) = state { return reason }
                return nil
            }
            .first()
            .sink { _ in enrollExp.fulfill() }
            .store(in: &cancellables)

        sut.password = "TestPassword1!"
        sut.unlock()
        await fulfillment(of: [enrollExp], timeout: 3.0)

        // Now dismiss and confirm vault transition.
        let vaultExp = expectation(description: "transitions to vault after dismiss")
        sut.$flowState
            .filter { $0 == .vault }
            .first()
            .sink { _ in vaultExp.fulfill() }
            .store(in: &cancellables)

        sut.dismissEnrollmentPrompt()
        await fulfillment(of: [vaultExp], timeout: 3.0)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "biometricEnrollmentPromptShown"))
        if case .enrollmentPrompt = sut.flowState {
            XCTFail("flowState should not still be .enrollmentPrompt after dismiss")
        }
    }

    func testConfirmEnrollBiometric_transitionsToVault() async {
        mockAuth.stubbedDeviceBiometricCapable = true
        UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
        UserDefaults.standard.set(false, forKey: "biometricEnrollmentPromptShown")

        let enrollExp = expectation(description: "reaches enrollmentPrompt state")
        sut.$flowState
            .compactMap { state -> EnrollmentReason? in
                if case .enrollmentPrompt(let reason) = state { return reason }
                return nil
            }
            .first()
            .sink { _ in enrollExp.fulfill() }
            .store(in: &cancellables)

        sut.password = "TestPassword1!"
        sut.unlock()
        await fulfillment(of: [enrollExp], timeout: 3.0)

        let vaultExp = expectation(description: "transitions to vault after confirm")
        sut.$flowState
            .filter { $0 == .vault }
            .first()
            .sink { _ in vaultExp.fulfill() }
            .store(in: &cancellables)

        sut.confirmEnrollBiometric()
        await fulfillment(of: [vaultExp], timeout: 3.0)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "biometricEnrollmentPromptShown"))
    }

    func testEnrollmentPrompt_reason_isFirstTime_onInitialUnlock() async {
        mockAuth.stubbedDeviceBiometricCapable = true
        UserDefaults.standard.set(false, forKey: "biometricUnlockEnabled")
        UserDefaults.standard.set(false, forKey: "biometricEnrollmentPromptShown")

        let exp = expectation(description: "reaches enrollmentPrompt with .firstTime reason")
        sut.$flowState
            .compactMap { state -> EnrollmentReason? in
                if case .enrollmentPrompt(let reason) = state { return reason }
                return nil
            }
            .first()
            .sink { reason in
                XCTAssertEqual(reason, .firstTime)
                exp.fulfill()
            }
            .store(in: &cancellables)

        sut.password = "TestPassword1!"
        sut.unlock()
        await fulfillment(of: [exp], timeout: 3.0)
    }
}
