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

    let apiClient:     PrizmAPIClientImpl
    let crypto:        PrizmCryptoServiceImpl
    let keychain:      KeychainServiceImpl
    let vaultStore:    VaultRepositoryImpl
    let faviconLoader: FaviconLoader
    /// In-memory cache mapping cipher ID → 64-byte effective key.
    /// Populated at sync time by `SyncRepositoryImpl`; cleared on vault lock alongside
    /// `vaultStore` so key material does not outlive the vault session (Constitution §III).
    let vaultKeyCache: VaultKeyCache

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
    let syncTimestampRepository:         SyncTimestampRepositoryImpl
    let getLastSyncDateUseCase:          any GetLastSyncDateUseCase

    // MARK: - Attachment use cases

    let uploadAttachmentUseCase:   UploadAttachmentUseCaseImpl
    let downloadAttachmentUseCase: DownloadAttachmentUseCaseImpl
    let deleteAttachmentUseCase:   DeleteAttachmentUseCaseImpl

    // MARK: - Temp file lifecycle

    /// Singleton temp-file manager — injected into `AttachmentRowViewModel` via the
    /// `TempFileManaging` protocol to keep Presentation decoupled from AppKit (Constitution §II).
    let tempFileManager: AttachmentTempFileManager

    // MARK: - Init

    init() {
        let api           = PrizmAPIClientImpl()
        let crypto        = PrizmCryptoServiceImpl()
        let keychain      = KeychainServiceImpl()
        let vault         = VaultRepositoryImpl(apiClient: api, crypto: crypto)
        let keyCache      = VaultKeyCache()
        let vaultKeyService = VaultKeyServiceImpl(cache: keyCache, crypto: crypto)

        let auth = AuthRepositoryImpl(
            apiClient: api,
            crypto:    crypto,
            keychain:  keychain
        )
        let sync = SyncRepositoryImpl(
            apiClient:       api,
            crypto:          crypto,
            vaultRepository: vault,
            vaultKeyCache:   keyCache
        )

        let attachmentRepo = AttachmentRepositoryImpl(
            apiClient:       api,
            crypto:          crypto,
            vaultRepository: vault
        )

        // Resolve the stored account email for per-account timestamp scoping.
        // Falls back to an empty string if no account is stored yet (first launch before login);
        // the timestamp will be recorded under the correct key after login completes.
        let accountEmail = auth.storedAccount()?.email ?? ""
        let syncTimestamp = SyncTimestampRepositoryImpl(email: accountEmail)

        self.apiClient       = api
        self.crypto          = crypto
        self.keychain        = keychain
        self.vaultStore      = vault
        self.faviconLoader   = FaviconLoader()
        self.vaultKeyCache   = keyCache
        self.authRepository  = auth
        self.syncRepository  = sync
        self.syncUseCase                     = SyncUseCaseImpl(sync: sync)
        self.loginUseCase                    = LoginUseCaseImpl(auth: auth, sync: sync)
        self.unlockUseCase                   = UnlockUseCaseImpl(auth: auth, sync: sync)
        self.searchVaultUseCase              = SearchVaultUseCaseImpl(vault: vault)
        self.editVaultItemUseCase            = EditVaultItemUseCaseImpl(repository: vault)
        self.createVaultItemUseCase          = CreateVaultItemUseCaseImpl(repository: vault)
        self.deleteVaultItemUseCase          = DeleteVaultItemUseCaseImpl(repository: vault)
        self.permanentDeleteVaultItemUseCase = PermanentDeleteVaultItemUseCaseImpl(repository: vault)
        self.restoreVaultItemUseCase         = RestoreVaultItemUseCaseImpl(repository: vault)
        self.syncTimestampRepository         = syncTimestamp
        self.getLastSyncDateUseCase          = GetLastSyncDateUseCaseImpl(repository: syncTimestamp)
        // Attachment use cases — Upload and Download inject VaultKeyService;
        // Delete does NOT (no key material required, Constitution §VI).
        self.uploadAttachmentUseCase   = UploadAttachmentUseCaseImpl(repository: attachmentRepo, vaultKeyService: vaultKeyService)
        self.downloadAttachmentUseCase = DownloadAttachmentUseCaseImpl(repository: attachmentRepo, vaultKeyService: vaultKeyService)
        self.deleteAttachmentUseCase   = DeleteAttachmentUseCaseImpl(repository: attachmentRepo)
        self.tempFileManager           = AttachmentTempFileManager()
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
            restore:         restoreVaultItemUseCase,
            syncTimestamp:   syncTimestampRepository,
            getLastSyncDate: getLastSyncDateUseCase
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

    /// Creates an `AttachmentAddViewModel` for the given cipher ID.
    ///
    /// Injected into `ItemDetailView` as a factory closure so the Presentation layer
    /// remains decoupled from the Data layer (Constitution §II).
    @MainActor
    func makeAddAttachmentViewModel(for cipherId: String) -> AttachmentAddViewModel {
        AttachmentAddViewModel(cipherId: cipherId, uploadUseCase: uploadAttachmentUseCase)
    }

    /// Creates an `AttachmentBatchViewModel` for the given cipher ID.
    ///
    /// Injected into `ItemDetailView` as a factory closure so the Presentation layer
    /// remains decoupled from the Data layer (Constitution §II).
    @MainActor
    func makeBatchAttachmentViewModel(for cipherId: String) -> AttachmentBatchViewModel {
        AttachmentBatchViewModel(cipherId: cipherId, uploadUseCase: uploadAttachmentUseCase)
    }

    /// Creates an `AttachmentRowViewModel` for the given cipher + attachment pair.
    ///
    /// Injected into the attachment row at render time so each row gets its own ViewModel
    /// instance with the correct cipher ID and attachment state.
    @MainActor
    func makeAttachmentRowViewModel(cipherId: String, attachment: Attachment) -> AttachmentRowViewModel {
        AttachmentRowViewModel(
            cipherId:        cipherId,
            attachment:      attachment,
            downloadUseCase: downloadAttachmentUseCase,
            deleteUseCase:   deleteAttachmentUseCase,
            uploadUseCase:   uploadAttachmentUseCase,
            tempFileManager: tempFileManager
        )
    }
}
