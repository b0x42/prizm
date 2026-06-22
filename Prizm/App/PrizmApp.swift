//
//  PrizmApp.swift
//  Prizm
//
//  Created by Benjamin on 15.03.26.
//

import AppKit
import Combine
import SwiftUI
import os.log

@main
struct PrizmApp: App {

    @StateObject private var container: AppContainer
    @StateObject private var rootVM:    RootViewModel
    @State       private var optionKeyMonitor = OptionKeyMonitor()

    // Used by the About menu item to open the custom About window scene.
    @Environment(\.openWindow) private var openWindow

    init() {
        let c = AppContainer()
        _container = StateObject(wrappedValue: c)
        _rootVM    = StateObject(wrappedValue: RootViewModel(container: c))
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .frame(minWidth: 480, minHeight: 360)
                .environment(optionKeyMonitor)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // Replace the default "About Prizm" panel with our custom SwiftUI window.
            CommandGroup(replacing: .appInfo) {
                Button("About Prizm") {
                    openWindow(id: "about")
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }

            CommandGroup(after: .appInfo) {
                Button("Sign Out…") {
                    rootVM.confirmSignOut()
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
                .disabled(!rootVM.isSignedIn)

                Button("Lock Vault") {
                    rootVM.lockVault()
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!rootVM.isVaultUnlocked)
            }

            // "Item" menu — sits in the standard macOS menu bar next to Edit/View/Window.
            // Edit opens the edit sheet for the selected vault item (⌘E).
            // Save persists in-flight edits (⌘S).
            // Buttons are disabled by `rootVM` Combine subscriptions that track
            // item selection and edit-sheet state.
            CommandMenu("Item") {
                Button("Edit") {
                    rootVM.vaultBrowserVM.triggerEdit()
                }
                .disabled(!rootVM.menuBarCanEdit)
                .keyboardShortcut("e", modifiers: .command)

                Button("Save") {
                    rootVM.vaultBrowserVM.triggerSave()
                }
                .disabled(!rootVM.menuBarCanSave)
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("Copy Username") {
                    rootVM.copySelectedField(.username)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!rootVM.selectedFieldAvailable(.username))

                Button("Copy Password") {
                    rootVM.copySelectedField(.password)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(!rootVM.selectedFieldAvailable(.password))

                Button("Copy Code") {
                    rootVM.copySelectedField(.totp)
                }
                .keyboardShortcut("c", modifiers: [.command, .control])
                .disabled(!rootVM.selectedFieldAvailable(.totp))

                Button("Copy Website") {
                    rootVM.copySelectedField(.website)
                }
                .keyboardShortcut("c", modifiers: [.command, .option, .shift])
                .disabled(!rootVM.selectedFieldAvailable(.website))
            }
        }

        // Custom About window — opened via Prizm → About Prizm.
        // hiddenTitleBar: AboutView provides its own header with the app icon and name,
        // so the system title bar would be redundant.
        // contentSize resizability: window sizes to AboutView's fixed 380pt width; no
        // free resize since the content is a fixed-layout info panel.
        Window("About Prizm", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Settings window — opened via ⌘, (macOS convention) or the gear toolbar button.
        // The Settings scene does not inherit the WindowGroup environment, so we pass
        // the container explicitly via .environmentObject().
        Settings {
            SettingsView(authRepository: container.authRepository)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch rootVM.screen {
        case .login:
            LoginView(viewModel: rootVM.loginVM)

        case .loading:
            ProgressView("Signing in…")
                .frame(minWidth: 480, minHeight: 360)

        case .totpPrompt:
            TOTPPromptView(viewModel: rootVM.loginVM)

        case .otpPrompt:
            NewDeviceOTPView(viewModel: rootVM.loginVM)

        case .unlock:
            if let unlockVM = rootVM.unlockVM {
                UnlockView(viewModel: unlockVM)
            }

        case .syncing(let message):
            SyncProgressView(message: message)

        case .vault:
            VaultBrowserView(
                viewModel:         rootVM.vaultBrowserVM,
                faviconLoader:     container.faviconLoader,
                makeEditViewModel: { [vaultBrowserVM = rootVM.vaultBrowserVM] item in
                    let vm = container.makeItemEditViewModel(
                        for: item,
                        folders: vaultBrowserVM.folders,
                        organizations: vaultBrowserVM.organizations,
                        collections: vaultBrowserVM.collections
                    )
                    // Wire the list-pane refresh callback to the shared VaultBrowserViewModel.
                    vm.onSaveSuccess = { [weak vaultBrowserVM] updatedItem in
                        vaultBrowserVM?.handleItemSaved(updatedItem)
                    }
                    return vm
                },
                makeCreateViewModel: { [vaultBrowserVM = rootVM.vaultBrowserVM] type, contextId in
                    // contextId is either a folderId (personal item) or collectionId (org item),
                    // determined by whether the current sidebar selection is a collection.
                    let cols = vaultBrowserVM.collections
                    let isCollection = contextId != nil && cols.contains(where: { $0.id == contextId })
                    let vm: ItemEditViewModel
                    if isCollection {
                        vm = container.makeItemCreateViewModel(
                            for: type, collectionId: contextId,
                            folders: vaultBrowserVM.folders, organizations: vaultBrowserVM.organizations, collections: cols
                        )
                    } else {
                        vm = container.makeItemCreateViewModel(
                            for: type, folderId: contextId,
                            folders: vaultBrowserVM.folders, organizations: vaultBrowserVM.organizations, collections: cols
                        )
                    }
                    vm.onSaveSuccess = { [weak vaultBrowserVM] item in
                        vaultBrowserVM?.handleItemSaved(item)
                    }
                    return vm
                },
                makeAddAttachmentViewModel: { cipherId in
                    container.makeAddAttachmentViewModel(for: cipherId)
                },
                makeBatchAttachmentViewModel: { cipherId in
                    container.makeBatchAttachmentViewModel(for: cipherId)
                },
                makeAttachmentRowViewModel: { cipherId, attachment in
                    container.makeAttachmentRowViewModel(cipherId: cipherId, attachment: attachment)
                }
            )
        }
    }
}

// MARK: - RootViewModel

/// Dependencies required by `RootViewModel` — extracted for testability.
@MainActor
protocol RootViewModelDependencies: AnyObject {
    var authRepo: any AuthRepository { get }
    var vaultRepo: any VaultRepository { get }
    /// The per-cipher attachment key cache. Cleared on vault lock alongside the vault store.
    var vaultKeyCache: VaultKeyCache { get }
    /// The per-organisation symmetric key cache. Cleared on vault lock alongside the vault store.
    var orgKeyCache: OrgKeyCache { get }
    func makeLoginViewModel() -> LoginViewModel
    func makeUnlockViewModel(account: Account) -> UnlockViewModel
    func makeVaultBrowserViewModel() -> VaultBrowserViewModel
    /// Returns a fresh sync timestamp repository and use case scoped to the given email.
    /// Called after login/unlock to re-scope to the correct account before the first sync.
    func makeSyncTimestampDependencies(for email: String) -> (repository: any SyncTimestampRepository, useCase: any GetLastSyncDateUseCase)
}

extension AppContainer: RootViewModelDependencies {
    var authRepo: any AuthRepository { authRepository }
    var vaultRepo: any VaultRepository { vaultStore }
}

/// Top-level state machine that decides which screen to show.
///
/// On launch: checks for a stored session via `AuthRepository.storedAccount()`.
/// - Session found → `UnlockView` (User Story 2)
/// - No session    → `LoginView`  (User Story 1)
@MainActor
final class RootViewModel: ObservableObject {

    enum Screen {
        case login
        case loading
        case totpPrompt
        case otpPrompt
        case unlock
        case syncing(message: String)
        case vault
    }

    @Published var screen: Screen

    // MARK: - "Item" menu state

    /// Whether the Edit command should be enabled: an item is selected and the edit sheet is closed.
    @Published private(set) var menuBarCanEdit: Bool = false

    /// Whether the Save command should be enabled: the edit sheet is currently open.
    @Published private(set) var menuBarCanSave: Bool = false

    /// The login content of the currently selected item, or nil. Drives copy command disabled state.
    @Published private(set) var selectedLogin: LoginContent?

    private let logger = Logger(subsystem: "com.prizm", category: "RootViewModel")

    let loginVM:          LoginViewModel
    @Published var unlockVM: UnlockViewModel?
    let vaultBrowserVM:   VaultBrowserViewModel

    private let container: any RootViewModelDependencies
    /// Combine subscriptions — held for the lifetime of this object.
    /// Using Combine (not SwiftUI .onChange) so transitions fire regardless
    /// of whether the source view is currently in the view hierarchy.
    private var cancellables = Set<AnyCancellable>()
    /// System notification observers for auto-lock (sleep, screensaver, screen lock).
    nonisolated(unsafe) private var sleepObserver: NSObjectProtocol?
    nonisolated(unsafe) private var screensaverObserver: NSObjectProtocol?
    nonisolated(unsafe) private var screenLockObserver: NSObjectProtocol?

    init(container: any RootViewModelDependencies) {
        self.container      = container
        self.loginVM        = container.makeLoginViewModel()
        self.vaultBrowserVM = container.makeVaultBrowserViewModel()

        // Check for stored session at launch.
        if let account = container.authRepo.storedAccount() {
            self.screen   = .unlock
            self.unlockVM = container.makeUnlockViewModel(account: account)
        } else {
            self.screen   = .login
            self.unlockVM = nil
        }

        subscribeToFlowStates()
    }

    deinit {
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let screensaverObserver { DistributedNotificationCenter.default().removeObserver(screensaverObserver) }
        if let screenLockObserver { DistributedNotificationCenter.default().removeObserver(screenLockObserver) }
    }

    // MARK: - Combine subscriptions

    private func subscribeToFlowStates() {
        // Login flow — observe for the lifetime of the app (loginVM is never replaced).
        loginVM.$flowState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleLoginFlow(state) }
            .store(in: &cancellables)

        // Unlock flow — re-subscribe whenever unlockVM is assigned.
        $unlockVM
            .compactMap { $0 }
            .flatMap { $0.$flowState }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleUnlockFlow(state) }
            .store(in: &cancellables)

        // canEdit: item selected AND edit sheet not yet open.
        // canSave: edit sheet is open.
        // Both are derived by watching editSheetOpen and itemSelection independently.
        // `for await` on @Published.values avoids Combine callbacks (CLAUDE.md async/await rule).
        Task { [weak self, vaultBrowserVM] in
            for await open in vaultBrowserVM.$editSheetOpen.values {
                guard let self else { break }
                self.menuBarCanSave = open
                self.menuBarCanEdit = vaultBrowserVM.itemSelection != nil && !open
            }
        }
        Task { [weak self, vaultBrowserVM] in
            for await selection in vaultBrowserVM.$itemSelection.values {
                guard let self else { break }
                self.menuBarCanEdit = selection != nil && !vaultBrowserVM.editSheetOpen
                if case .login(let login) = selection?.content {
                    self.selectedLogin = login
                } else {
                    self.selectedLogin = nil
                }
            }
        }

        // Auto-lock on Mac sleep.
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.lockVault() } }

        // Auto-lock on screensaver start.
        screensaverObserver = DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.lockVault() } }

        // Auto-lock on screen lock (⌃⌘Q / Lock Screen menu).
        screenLockObserver = DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.lockVault() } }
    }

    /// Re-scopes the sync timestamp to the current account and records a successful sync,
    /// then transitions to the vault screen.
    ///
    /// Called from both `handleLoginFlow` and `handleUnlockFlow` — the vault transition
    /// logic is identical in both flows. `caller` is included in the error log so the
    /// originating flow is identifiable when the account is unexpectedly missing.
    private func transitionToVault(caller: String) {
        // Re-scope before recording: on first login the AppContainer was initialised without
        // a known email; this corrects the UserDefaults key before handleSyncCompleted writes to it.
        if let email = container.authRepo.storedAccount()?.email {
            let deps = container.makeSyncTimestampDependencies(for: email)
            vaultBrowserVM.updateSyncTimestamp(repository: deps.repository, useCase: deps.useCase)
        } else {
            // Unexpected: vault transition reached with no stored account — timestamp will
            // be written under the fallback empty-email key. Should not occur in normal flow.
            logger.error("\(caller, privacy: .public)(.vault): no stored account; sync timestamp not re-scoped")
        }
        screen = .vault
        // Defer handleSyncCompleted to the next run-loop cycle so that the initial
        // VaultBrowserView layout pass (triggered by `screen = .vault` above) commits
        // before any @Published mutations from async vault reads arrive.
        //
        // Root cause: VaultRepositoryImpl is an `actor`, so every refresh Task suspends
        // at a cross-actor hop; the continuations resume on @MainActor asynchronously.
        // If they land while SwiftUI is computing its first layout pass for VaultBrowserView,
        // SwiftUI emits "Publishing changes from within view updates is not allowed" →
        // undefined behaviour → heap corruption → z_ccm_xcma_malloc_freelist EXC_BREAKPOINT.
        //
        // DispatchQueue.main.async (not a Swift Task) is intentional: it guarantees
        // the block runs between run-loop iterations, after the current CATransaction
        // (which drives the SwiftUI layout commit) has flushed.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.vaultBrowserVM.handleSyncCompleted(syncedAt: Date())
            }
        }
    }

    func handleLoginFlow(_ state: LoginFlowState) {
        switch state {
        case .login:       screen = .login
        case .loading:     screen = .loading
        case .totpPrompt:  screen = .totpPrompt
        case .otpPrompt:   screen = .otpPrompt
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:       transitionToVault(caller: "handleLoginFlow")
        }
        logger.info("Screen transition → \(String(describing: state))")
    }

    /// Whether the user has an active session (vault or unlock screen).
    var isSignedIn: Bool {
        switch screen {
        case .vault, .unlock, .syncing: return true
        default: return false
        }
    }

    /// Shows a confirmation alert before signing out (FR-014).
    func confirmSignOut() {
        let alert = NSAlert()
        alert.messageText = "Sign Out"
        alert.informativeText = "All local data will be cleared."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        signOut()
    }

    /// Clears all session data and returns to the login screen.
    func signOut() {
        Task {
            do {
                try await container.authRepo.signOut()
            } catch {
                logger.error("Sign-out error: \(error.localizedDescription, privacy: .public)")
            }
            await container.vaultRepo.clearVault()
            await container.vaultKeyCache.clear()
            unlockVM = nil
            screen   = .login
            logger.info("Sign out completed")
        }
    }

    // MARK: - Lock

    /// Zeros in-memory key material, clears the vault cache, and transitions to the unlock screen.
    /// No-op if the vault is not currently unlocked.
    func lockVault() {
        guard isVaultUnlocked else { return }
        Task {
            await container.authRepo.lockVault()
            await container.vaultRepo.clearVault()
            // Clear all key caches in the same lock path as the vault store.
            // Key material must not outlive the vault session (Constitution §III).
            await container.vaultKeyCache.clear()
            await container.orgKeyCache.clear()
            if let account = container.authRepo.storedAccount() {
                unlockVM = container.makeUnlockViewModel(account: account)
                screen = .unlock
            } else {
                screen = .login
            }
            logger.info("Vault locked")
        }
    }

    /// Whether the vault is currently unlocked (vault browser or sync in progress).
    var isVaultUnlocked: Bool {
        switch screen {
        case .vault, .syncing: return true
        default: return false
        }
    }

    func handleUnlockFlow(_ state: UnlockFlowState) {
        switch state {
        case .unlock:       screen = .unlock
        case .loading:      screen = .unlock   // stay on unlock screen with spinner
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:        transitionToVault(caller: "handleUnlockFlow")
        case .login:
            // "Sign in with a different account" — reset to login.
            unlockVM = nil
            screen   = .login
        }
        logger.info("Screen transition → \(String(describing: state))")
    }

    // MARK: - Copy field from selected item

    enum CopyableField {
        case username, password, totp, website
    }

    func copySelectedField(_ field: CopyableField) {
        guard let value = selectedFieldValue(field) else { return }
        vaultBrowserVM.copy(value)
    }

    func selectedFieldAvailable(_ field: CopyableField) -> Bool {
        selectedFieldValue(field) != nil
    }

    private func selectedFieldValue(_ field: CopyableField) -> String? {
        guard let login = selectedLogin else { return nil }

        switch field {
        case .username: return login.username
        case .password: return login.password
        case .totp:     return login.totp
        case .website:  return login.uris.first?.uri
        }
    }
}
