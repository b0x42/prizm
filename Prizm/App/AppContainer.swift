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
    let biometricKeychain: BiometricKeychainServiceImpl
    let vaultStore:    VaultRepositoryImpl
    let faviconLoader: FaviconLoader
    /// In-memory cache mapping cipher ID → 64-byte effective key.
    /// Populated at sync time by `SyncRepositoryImpl`; cleared on vault lock alongside
    /// `vaultStore` so key material does not outlive the vault session (Constitution §III).
    let vaultKeyCache: VaultKeyCache
    /// In-memory cache mapping organization ID → unwrapped 64-byte symmetric key.
    /// Populated at sync time; cleared on vault lock alongside `vaultKeyCache` (Constitution §III).
    let orgKeyCache: OrgKeyCache

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
    let createFolderUseCase:             CreateFolderUseCaseImpl
    let renameFolderUseCase:             RenameFolderUseCaseImpl
    let deleteFolderUseCase:             DeleteFolderUseCaseImpl
    let moveItemToFolderUseCase:         MoveItemToFolderUseCaseImpl
    let createCollectionUseCase:         CreateCollectionUseCaseImpl
    let renameCollectionUseCase:         RenameCollectionUseCaseImpl
    let deleteCollectionUseCase:         DeleteCollectionUseCaseImpl
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
        let biometricKeychain = BiometricKeychainServiceImpl()
        let vault         = VaultRepositoryImpl(apiClient: api, crypto: crypto, orgKeyCache: orgKeyCache)
        let keyCache      = VaultKeyCache()
        let orgKeyCache   = OrgKeyCache()
        let vaultKeyService = VaultKeyServiceImpl(cache: keyCache, crypto: crypto)

        let auth = AuthRepositoryImpl(
            apiClient: api,
            crypto:    crypto,
            keychain:  keychain,
            biometricKeychain: biometricKeychain
        )
        let sync = SyncRepositoryImpl(
            apiClient:       api,
            crypto:          crypto,
            vaultRepository: vault,
            vaultKeyCache:   keyCache,
            orgKeyCache:     orgKeyCache
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
        self.biometricKeychain = biometricKeychain
        self.vaultStore      = vault
        self.faviconLoader   = FaviconLoader()
        self.vaultKeyCache   = keyCache
        self.orgKeyCache     = orgKeyCache
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
        self.createFolderUseCase             = CreateFolderUseCaseImpl(repository: vault)
        self.renameFolderUseCase             = RenameFolderUseCaseImpl(repository: vault)
        self.deleteFolderUseCase             = DeleteFolderUseCaseImpl(repository: vault)
        self.moveItemToFolderUseCase         = MoveItemToFolderUseCaseImpl(repository: vault)
        self.createCollectionUseCase         = CreateCollectionUseCaseImpl(repository: vault)
        self.renameCollectionUseCase         = RenameCollectionUseCaseImpl(repository: vault)
        self.deleteCollectionUseCase         = DeleteCollectionUseCaseImpl(repository: vault)
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
        UnlockViewModel(auth: authRepository, sync: syncUseCase, account: account, embeddedBiometric: authRepository)
    }

    /// Creates a `VaultBrowserViewModel` backed by the live vault store.
    func makeVaultBrowserViewModel() -> VaultBrowserViewModel {
        VaultBrowserViewModel(
            vault:            vaultStore,
            search:           searchVaultUseCase,
            delete:           deleteVaultItemUseCase,
            permanentDelete:  permanentDeleteVaultItemUseCase,
            restore:          restoreVaultItemUseCase,
            createFolder:     createFolderUseCase,
            renameFolder:     renameFolderUseCase,
            deleteFolder:     deleteFolderUseCase,
            moveItem:         moveItemToFolderUseCase,
            createCollection: createCollectionUseCase,
            renameCollection: renameCollectionUseCase,
            deleteCollection: deleteCollectionUseCase,
            syncTimestamp:    syncTimestampRepository,
            getLastSyncDate:  getLastSyncDateUseCase
        )
    }

    /// Creates an `ItemEditViewModel` for the given item, wired with the live edit use case.
    /// The caller is responsible for setting `onSaveSuccess` to update the UI after a save.
    func makeItemEditViewModel(for item: VaultItem) -> ItemEditViewModel {
        let folders = (try? vaultStore.folders()) ?? []
        let orgs    = (try? vaultStore.organizations()) ?? []
        let cols    = (try? vaultStore.collections()) ?? []
        return ItemEditViewModel(item: item, useCase: editVaultItemUseCase, folders: folders,
                                 organizations: orgs, collections: cols)
    }

    /// Creates an `ItemEditViewModel` in create mode for the given item type.
    /// Pass `collectionId` to pre-fill the collection when creating from a collection context (task 5.9 / 7.2).
    func makeItemCreateViewModel(for type: ItemType, folderId: String? = nil,
                                 collectionId: String? = nil) -> ItemEditViewModel {
        let folders = (try? vaultStore.folders()) ?? []
        let orgs    = (try? vaultStore.organizations()) ?? []
        let cols    = (try? vaultStore.collections()) ?? []
        // Pre-populate org and collection when creating in a collection context.
        var orgId: String? = nil
        var colIds: [String] = []
        if let colId = collectionId,
           let col = cols.first(where: { $0.id == colId }) {
            orgId  = col.organizationId
            colIds = [colId]
        }
        return ItemEditViewModel(
            type: type, useCase: createVaultItemUseCase, folders: folders,
            folderId: folderId, organizationId: orgId, collectionIds: colIds,
            organizations: orgs, collections: cols
        )
    }

    // MARK: - AppKit panel defaults (App layer — Constitution §II)
    //
    // These closures wrap AppKit classes (NSOpenPanel, NSSavePanel, NSWorkspace) and are
    // injected into Presentation-layer ViewModels so the Presentation layer never imports
    // AppKit directly.

    /// Default multi-file picker using `NSOpenPanel`.
    @MainActor
    private static func defaultNSOpenPanel() -> [(url: URL, bytes: Int)] {
        let panel = NSOpenPanel()
        panel.canChooseFiles          = true
        panel.canChooseDirectories    = false
        panel.allowsMultipleSelection = true
        panel.message                 = "Choose files to attach"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.map { url in
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return (url, bytes)
        }
    }

    /// Default save panel using `NSSavePanel`.
    @MainActor
    private static func defaultSavePanel(suggestedName: String) -> URL? {
        let panel                  = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.message              = "Choose where to save the attachment"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Default single-file picker for retry using `NSOpenPanel`.
    @MainActor
    private static func defaultRetryOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles          = true
        panel.canChooseDirectories    = false
        panel.allowsMultipleSelection = false
        panel.message                 = "Select the file to re-upload"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Default file opener using `NSWorkspace`.
    @MainActor
    private static func defaultFileOpener(url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Creates an `AttachmentAddViewModel` for the given cipher ID.
    @MainActor
    func makeAddAttachmentViewModel(for cipherId: String) -> AttachmentAddViewModel {
        AttachmentAddViewModel(
            cipherId:      cipherId,
            uploadUseCase: uploadAttachmentUseCase,
            filePicker:    Self.defaultNSOpenPanel
        )
    }

    /// Creates an `AttachmentBatchViewModel` for the given cipher ID.
    @MainActor
    func makeBatchAttachmentViewModel(for cipherId: String) -> AttachmentBatchViewModel {
        AttachmentBatchViewModel(cipherId: cipherId, uploadUseCase: uploadAttachmentUseCase)
    }

    /// Creates an `AttachmentRowViewModel` for the given cipher + attachment pair.
    @MainActor
    func makeAttachmentRowViewModel(cipherId: String, attachment: Attachment) -> AttachmentRowViewModel {
        AttachmentRowViewModel(
            cipherId:        cipherId,
            attachment:      attachment,
            downloadUseCase: downloadAttachmentUseCase,
            deleteUseCase:   deleteAttachmentUseCase,
            uploadUseCase:   uploadAttachmentUseCase,
            tempFileManager: tempFileManager,
            fileSaver:       Self.defaultSavePanel,
            retryFilePicker: Self.defaultRetryOpenPanel,
            fileOpener:      Self.defaultFileOpener
        )
    }
}
