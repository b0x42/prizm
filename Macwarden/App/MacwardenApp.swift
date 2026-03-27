//
//  MacwardenApp.swift
//  Macwarden
//
//  Created by Benjamin on 15.03.26.
//

import AppKit
import Combine
import SwiftUI
import os.log

@main
struct MacwardenApp: App {

    @StateObject private var container: AppContainer
    @StateObject private var rootVM:    RootViewModel
    @State       private var optionKeyMonitor = OptionKeyMonitor()

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
            }
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
                    let vm = container.makeItemEditViewModel(for: item)
                    // Wire the list-pane refresh callback to the shared VaultBrowserViewModel.
                    vm.onSaveSuccess = { [weak vaultBrowserVM] updatedItem in
                        vaultBrowserVM?.handleItemSaved(updatedItem)
                    }
                    return vm
                },
                makeCreateViewModel: { [vaultBrowserVM = rootVM.vaultBrowserVM] type in
                    let vm = container.makeItemCreateViewModel(for: type)
                    vm.onSaveSuccess = { [weak vaultBrowserVM] item in
                        vaultBrowserVM?.handleItemSaved(item)
                    }
                    return vm
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
    func makeLoginViewModel() -> LoginViewModel
    func makeUnlockViewModel(account: Account) -> UnlockViewModel
    func makeVaultBrowserViewModel() -> VaultBrowserViewModel
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

    private let logger = Logger(subsystem: "com.macwarden", category: "RootViewModel")

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

    func handleLoginFlow(_ state: LoginFlowState) {
        switch state {
        case .login:       screen = .login
        case .loading:     screen = .loading
        case .totpPrompt:  screen = .totpPrompt
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:
            vaultBrowserVM.handleSyncCompleted(syncedAt: Date())
            screen = .vault
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
            container.vaultRepo.clearVault()
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
        case .vault:
            vaultBrowserVM.handleSyncCompleted(syncedAt: Date())
            screen = .vault
        case .login:
            // "Sign in with a different account" — reset to login.
            unlockVM = nil
            screen   = .login
        }
        logger.info("Screen transition → \(String(describing: state))")
    }
}
