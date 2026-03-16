import Foundation

/// Dependency injection container — wires together all Data-layer implementations
/// and exposes the Domain-layer protocols used by the Presentation layer.
///
/// Created once at app launch and passed down via `@StateObject` / environment.
/// All types are instantiated eagerly; nothing is lazy in Phase 4.
@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Data layer

    let apiClient:  BitwardenAPIClientImpl
    let crypto:     BitwardenCryptoServiceImpl
    let keychain:   KeychainServiceImpl
    let vaultStore: VaultRepositoryImpl

    // MARK: - Domain repositories (Data implementations)

    let authRepository: AuthRepositoryImpl
    let syncRepository: SyncRepositoryImpl

    // MARK: - Domain use cases

    let syncUseCase:  SyncUseCaseImpl
    let loginUseCase: LoginUseCaseImpl

    // MARK: - Init

    init() {
        let api      = BitwardenAPIClientImpl()
        let crypto   = BitwardenCryptoServiceImpl()
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
        self.authRepository  = auth
        self.syncRepository  = sync
        self.syncUseCase     = SyncUseCaseImpl(sync: sync)
        self.loginUseCase    = LoginUseCaseImpl(auth: auth, sync: sync)
    }

    // MARK: - Factory

    /// Creates a `LoginViewModel` pre-wired with the container's auth + sync.
    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(auth: authRepository, sync: syncUseCase)
    }
}
