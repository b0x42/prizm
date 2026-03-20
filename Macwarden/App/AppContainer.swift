import AppKit
import Combine
import Foundation

/// Dependency injection container — wires together all Data-layer implementations
/// and exposes the Domain-layer protocols used by the Presentation layer.
///
/// Created once at app launch and passed down via `@StateObject` / environment.
/// All types are instantiated eagerly; nothing is lazy in Phase 4.
@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Data layer

    let apiClient:     MacwardenAPIClientImpl
    let crypto:        MacwardenCryptoServiceImpl
    let keychain:      KeychainServiceImpl
    let vaultStore:    VaultRepositoryImpl
    let faviconLoader: FaviconLoader

    // MARK: - Domain repositories (Data implementations)

    let authRepository: AuthRepositoryImpl
    let syncRepository: SyncRepositoryImpl

    // MARK: - Domain use cases

    let syncUseCase:       SyncUseCaseImpl
    let loginUseCase:      LoginUseCaseImpl
    let unlockUseCase:     UnlockUseCaseImpl
    let searchVaultUseCase: SearchVaultUseCaseImpl

    // MARK: - Init

    init() {
        let api      = MacwardenAPIClientImpl()
        let crypto   = MacwardenCryptoServiceImpl()
        let keychain = KeychainServiceImpl()
        let vault    = VaultRepositoryImpl()

        let auth = AuthRepositoryImpl(
            apiClient: api,
            crypto:    crypto,
            keychain:  keychain
        )
        let sync = SyncRepositoryImpl(
            apiClient:       api,
            crypto:          crypto,
            vaultRepository: vault
        )

        self.apiClient       = api
        self.crypto          = crypto
        self.keychain        = keychain
        self.vaultStore      = vault
        self.faviconLoader   = FaviconLoader()
        self.authRepository  = auth
        self.syncRepository  = sync
        self.syncUseCase        = SyncUseCaseImpl(sync: sync)
        self.loginUseCase       = LoginUseCaseImpl(auth: auth, sync: sync)
        self.unlockUseCase      = UnlockUseCaseImpl(auth: auth, sync: sync)
        self.searchVaultUseCase = SearchVaultUseCaseImpl(vault: vault)
    }

    // MARK: - Factories

    /// Creates a `LoginViewModel` pre-wired with the container's login use case.
    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(loginUseCase: loginUseCase)
    }

    /// Creates an `UnlockViewModel` for a returning user with a stored session.
    func makeUnlockViewModel(account: Account) -> UnlockViewModel {
        UnlockViewModel(auth: authRepository, sync: syncUseCase, account: account)
    }

    /// Creates a `VaultBrowserViewModel` backed by the live vault store.
    func makeVaultBrowserViewModel() -> VaultBrowserViewModel {
        VaultBrowserViewModel(vault: vaultStore, search: searchVaultUseCase)
    }
}
