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

    // MARK: - Sync service

    /// Centralised sync coordinator. Injected into auth ViewModels and `VaultBrowserViewModel`.
    let syncService: SyncService

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
    let syncTimestampRepository:         SyncTimestampRepositoryImpl
    let getLastSyncDateUseCase:          any GetLastSyncDateUseCase

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

        // Resolve the stored account email for per-account timestamp scoping.
        // Falls back to an empty string if no account is stored yet (first launch before login);
        // the timestamp will be recorded under the correct key after login completes.
        let accountEmail = auth.storedAccount()?.email ?? ""
        let syncTimestamp = SyncTimestampRepositoryImpl(email: accountEmail)

        let syncUseCase = SyncUseCaseImpl(sync: sync)

        self.apiClient       = api
        self.crypto          = crypto
        self.keychain        = keychain
        self.vaultStore      = vault
        self.faviconLoader   = FaviconLoader()
        self.authRepository  = auth
        self.syncRepository  = sync
        self.syncService                     = SyncService(sync: syncUseCase)
        self.syncUseCase                     = syncUseCase
        self.loginUseCase                    = LoginUseCaseImpl(auth: auth)
        self.unlockUseCase                   = UnlockUseCaseImpl(auth: auth)
        self.searchVaultUseCase              = SearchVaultUseCaseImpl(vault: vault)
        self.editVaultItemUseCase            = EditVaultItemUseCaseImpl(repository: vault)
        self.createVaultItemUseCase          = CreateVaultItemUseCaseImpl(repository: vault)
        self.deleteVaultItemUseCase          = DeleteVaultItemUseCaseImpl(repository: vault)
        self.permanentDeleteVaultItemUseCase = PermanentDeleteVaultItemUseCaseImpl(repository: vault)
        self.restoreVaultItemUseCase         = RestoreVaultItemUseCaseImpl(repository: vault)
        self.syncTimestampRepository         = syncTimestamp
        self.getLastSyncDateUseCase          = GetLastSyncDateUseCaseImpl(repository: syncTimestamp)
    }

    // MARK: - Factories

    /// Returns a fresh `SyncTimestampRepository` and matching `GetLastSyncDateUseCase`
    /// scoped to the given account email.
    ///
    /// Called by `RootViewModel` after a successful login or unlock to ensure the
    /// `VaultBrowserViewModel` is always scoped to the correct account — not the
    /// fallback empty-email instance created before any account was known.
    func makeSyncTimestampDependencies(for email: String) -> (repository: any SyncTimestampRepository, useCase: any GetLastSyncDateUseCase) {
        let repo = SyncTimestampRepositoryImpl(email: email)
        return (repo, GetLastSyncDateUseCaseImpl(repository: repo))
    }

    /// Creates a `LoginViewModel` pre-wired with the container's login use case and sync service.
    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(loginUseCase: loginUseCase, syncService: syncService)
    }

    /// Creates an `UnlockViewModel` for a returning user with a stored session.
    func makeUnlockViewModel(account: Account) -> UnlockViewModel {
        UnlockViewModel(auth: authRepository, syncService: syncService, account: account)
    }

    /// Creates a `VaultBrowserViewModel` backed by the live vault store.
    func makeVaultBrowserViewModel() -> VaultBrowserViewModel {
        VaultBrowserViewModel(
            vault:           vaultStore,
            search:          searchVaultUseCase,
            delete:          deleteVaultItemUseCase,
            permanentDelete: permanentDeleteVaultItemUseCase,
            restore:         restoreVaultItemUseCase,
            syncTimestamp:   syncTimestampRepository,
            getLastSyncDate: getLastSyncDateUseCase,
            syncService:     syncService
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
