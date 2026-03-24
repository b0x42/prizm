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

    let syncUseCase:                     SyncUseCaseImpl
    let loginUseCase:                    LoginUseCaseImpl
    let unlockUseCase:                   UnlockUseCaseImpl
    let searchVaultUseCase:              SearchVaultUseCaseImpl
    let editVaultItemUseCase:            EditVaultItemUseCaseImpl
    let createVaultItemUseCase:          CreateVaultItemUseCaseImpl
    let deleteVaultItemUseCase:          DeleteVaultItemUseCaseImpl
    let permanentDeleteVaultItemUseCase: PermanentDeleteVaultItemUseCaseImpl
    let restoreVaultItemUseCase:         RestoreVaultItemUseCaseImpl

    // MARK: - Init

    init() {
        let api      = MacwardenAPIClientImpl()
        let crypto   = MacwardenCryptoServiceImpl()
        let keychain = KeychainServiceImpl()
        let vault    = VaultRepositoryImpl(apiClient: api, crypto: crypto)

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
        self.syncUseCase             = SyncUseCaseImpl(sync: sync)
        self.loginUseCase            = LoginUseCaseImpl(auth: auth, sync: sync)
        self.unlockUseCase           = UnlockUseCaseImpl(auth: auth, sync: sync)
        self.searchVaultUseCase      = SearchVaultUseCaseImpl(vault: vault)
        self.editVaultItemUseCase            = EditVaultItemUseCaseImpl(repository: vault)
        self.createVaultItemUseCase          = CreateVaultItemUseCaseImpl(repository: vault)
        self.deleteVaultItemUseCase          = DeleteVaultItemUseCaseImpl(repository: vault)
        self.permanentDeleteVaultItemUseCase = PermanentDeleteVaultItemUseCaseImpl(repository: vault)
        self.restoreVaultItemUseCase         = RestoreVaultItemUseCaseImpl(repository: vault)
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
        VaultBrowserViewModel(
            vault:           vaultStore,
            search:          searchVaultUseCase,
            delete:          deleteVaultItemUseCase,
            permanentDelete: permanentDeleteVaultItemUseCase,
            restore:         restoreVaultItemUseCase
        )
    }

    /// Creates an `ItemEditViewModel` for the given item, wired with the live edit use case.
    /// The caller is responsible for setting `onSaveSuccess` to update the UI after a save.
    func makeItemEditViewModel(for item: VaultItem) -> ItemEditViewModel {
        ItemEditViewModel(item: item, useCase: editVaultItemUseCase)
    }

    /// Creates an `ItemEditViewModel` in create mode for the given item type.
    func makeItemCreateViewModel(for type: ItemType) -> ItemEditViewModel {
        ItemEditViewModel(type: type, useCase: createVaultItemUseCase)
    }
}
