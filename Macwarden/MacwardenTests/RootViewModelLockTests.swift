import XCTest
@testable import Macwarden

/// Unit tests for `RootViewModel.lockVault()`.
@MainActor
final class RootViewModelLockTests: XCTestCase {

    private var mockAuth: MockAuthRepository!
    private var mockVault: MockVaultRepository!
    private var sut: RootViewModel!

    private let stubAccount = Account(
        userId: "user-001",
        email: "alice@example.com",
        name: nil,
        serverEnvironment: ServerEnvironment(
            base: URL(string: "https://vault.example.com")!,
            overrides: nil
        )
    )

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        mockVault = MockVaultRepository()
        let deps = MockRootDependencies(auth: mockAuth, vault: mockVault)
        sut = RootViewModel(container: deps)
    }

    // MARK: - 1.1 lockVault() transitions screen to .unlock

    func testLockVault_transitionsToUnlock() async throws {
        mockAuth.stubbedStoredAccount = stubAccount
        sut.screen = .vault

        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        guard case .unlock = sut.screen else {
            return XCTFail("Expected .unlock, got \(sut.screen)")
        }
    }

    // MARK: - 1.2 lockVault() is a no-op when screen != .vault

    func testLockVault_noOpWhenLogin() async throws {
        sut.screen = .login
        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        guard case .login = sut.screen else {
            return XCTFail("Expected .login, got \(sut.screen)")
        }
    }

    func testLockVault_noOpWhenUnlock() async throws {
        sut.screen = .unlock
        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        guard case .unlock = sut.screen else {
            return XCTFail("Expected .unlock, got \(sut.screen)")
        }
    }

    // MARK: - 1.3 lockVault() calls authRepository.lockVault() and vaultStore.clearVault()

    func testLockVault_callsLockAndClear() async throws {
        sut.screen = .vault

        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAuth.lockVaultCalledCount, 1)
        XCTAssertTrue(mockVault.clearVaultCalled)
    }

    // MARK: - 1.4 lockVault() creates a new unlockVM from the stored account

    func testLockVault_createsUnlockVM() async throws {
        mockAuth.stubbedStoredAccount = stubAccount
        sut.screen = .vault
        sut.unlockVM = nil

        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNotNil(sut.unlockVM)
    }

    // MARK: - 1.5 lockVault() falls back to .login when storedAccount() returns nil

    func testLockVault_fallsBackToLogin_whenNoStoredAccount() async throws {
        mockAuth.stubbedStoredAccount = nil
        sut.screen = .vault

        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        guard case .login = sut.screen else {
            return XCTFail("Expected .login, got \(sut.screen)")
        }
    }

    // MARK: - lockVault() works from .syncing state

    func testLockVault_worksFromSyncing() async throws {
        mockAuth.stubbedStoredAccount = stubAccount
        sut.screen = .syncing(message: "Syncing…")

        sut.lockVault()
        try await Task.sleep(for: .milliseconds(50))

        guard case .unlock = sut.screen else {
            return XCTFail("Expected .unlock, got \(sut.screen)")
        }
    }
}

// MARK: - Mock Dependencies

@MainActor
private final class MockRootDependencies: RootViewModelDependencies {
    let authRepo: any AuthRepository
    let vaultRepo: any VaultRepository

    private let mockLoginUseCase = MockLoginUseCase()
    private let mockSyncUseCase = MockSyncUseCase()
    private let mockVault: MockVaultRepository

    init(auth: MockAuthRepository, vault: MockVaultRepository) {
        self.authRepo = auth
        self.vaultRepo = vault
        self.mockVault = vault
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(loginUseCase: mockLoginUseCase)
    }

    func makeUnlockViewModel(account: Account) -> UnlockViewModel {
        UnlockViewModel(auth: authRepo as! MockAuthRepository, sync: mockSyncUseCase, account: account)
    }

    func makeVaultBrowserViewModel() -> VaultBrowserViewModel {
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        return VaultBrowserViewModel(
            vault:           mockVault,
            search:          StubSearchUseCase(),
            delete:          StubDeleteUseCase(),
            permanentDelete: StubPermanentDeleteUseCase(),
            restore:         StubRestoreUseCase(),
            syncTimestamp:   syncRepo,
            getLastSyncDate: GetLastSyncDateUseCaseImpl(repository: syncRepo)
        )
    }

    func makeSyncTimestampDependencies(for email: String) -> (repository: any SyncTimestampRepository, useCase: any GetLastSyncDateUseCase) {
        let repo = MockSyncTimestampRepository(storedDate: nil)
        return (repo, GetLastSyncDateUseCaseImpl(repository: repo))
    }
}

// Minimal stubs for VaultBrowserViewModel dependencies.
@MainActor private final class StubSearchUseCase: SearchVaultUseCase {
    func execute(query: String, in selection: SidebarSelection) throws -> [VaultItem] { [] }
}
@MainActor private final class StubDeleteUseCase: DeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}
@MainActor private final class StubPermanentDeleteUseCase: PermanentDeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}
@MainActor private final class StubRestoreUseCase: RestoreVaultItemUseCase {
    func execute(id: String) async throws {}
}
