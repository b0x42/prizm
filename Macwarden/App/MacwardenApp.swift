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

    init() {
        let c = AppContainer()
        _container = StateObject(wrappedValue: c)
        _rootVM    = StateObject(wrappedValue: RootViewModel(container: c))
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .frame(minWidth: 480, minHeight: 360)
                .containerBackground(.thinMaterial, for: .window)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Sign Out…") {
                    rootVM.confirmSignOut()
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
                .disabled(!rootVM.isSignedIn)
            }
        }

        // "Item" menu bar extra — visible only while the vault is unlocked (spec §9.2).
        // `if` in SceneBuilder IS supported; the earlier compile error was caused by
        // accessing a nested @StateObject chain (container.menuBarViewModel.isVaultUnlocked).
        // Now that menuBarIsVaultUnlocked is a direct @Published on the @StateObject rootVM,
        // this compiles and reactively hides/shows the extra on lock/unlock.
        // Note: isInserted: Binding only gates user-removal (macOS 13 feature) — it does
        // not actually show/hide the extra on value changes.
        if rootVM.menuBarIsVaultUnlocked {
            MenuBarExtra("Item", systemImage: "key.fill") {
                Button("Edit") {
                    container.menuBarViewModel.onEdit?()
                }
                .disabled(!rootVM.menuBarCanEdit)
                // Renders ⌘E inline in the dropdown (spec §9.3).
                .keyboardShortcut("e", modifiers: .command)

                Button("Save") {
                    container.menuBarViewModel.onSave?()
                }
                .disabled(!rootVM.menuBarCanSave)
                // Renders ⌘S inline in the dropdown (spec §9.4).
                .keyboardShortcut("s", modifiers: .command)
            }
            .menuBarExtraStyle(.menu)
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
                }
            )
        }
    }
}

// MARK: - RootViewModel

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

    // MARK: - Menu bar extra state (forwarded from MenuBarViewModel)
    //
    // @ObservedObject does not drive re-renders in an App struct's SceneBuilder body —
    // only @StateObject does. These three properties forward MenuBarViewModel's published
    // state into RootViewModel (a @StateObject) so the SceneBuilder reacts correctly.

    /// Whether the "Item" MenuBarExtra should be visible (vault unlocked).
    @Published private(set) var menuBarIsVaultUnlocked: Bool = false
    /// Whether the Edit action should be enabled (item selected, sheet closed).
    @Published private(set) var menuBarCanEdit: Bool = false
    /// Whether the Save action should be enabled (sheet open).
    @Published private(set) var menuBarCanSave: Bool = false

    private let logger = Logger(subsystem: "com.macwarden", category: "RootViewModel")

    let loginVM:          LoginViewModel
    @Published var unlockVM: UnlockViewModel?
    let vaultBrowserVM:   VaultBrowserViewModel

    private let container: AppContainer
    /// Combine subscriptions — held for the lifetime of this object.
    /// Using Combine (not SwiftUI .onChange) so transitions fire regardless
    /// of whether the source view is currently in the view hierarchy.
    private var cancellables = Set<AnyCancellable>()

    init(container: AppContainer) {
        self.container      = container
        self.loginVM        = container.makeLoginViewModel()
        self.vaultBrowserVM = container.makeVaultBrowserViewModel()

        // Check for stored session at launch.
        if let account = container.authRepository.storedAccount() {
            self.screen   = .unlock
            self.unlockVM = container.makeUnlockViewModel(account: account)
        } else {
            self.screen   = .login
            self.unlockVM = nil
        }

        subscribeToFlowStates()
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

        // canEdit: item selected AND edit sheet not yet open (spec §9.3).
        vaultBrowserVM.$itemSelection
            .combineLatest(vaultBrowserVM.$editSheetOpen)
            .map { selection, sheetOpen in selection != nil && !sheetOpen }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canEdit in self?.container.menuBarViewModel.canEdit = canEdit }
            .store(in: &cancellables)

        // canSave: edit sheet is open (save guard in ItemEditViewModel handles finer checks).
        vaultBrowserVM.$editSheetOpen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] open in self?.container.menuBarViewModel.canSave = open }
            .store(in: &cancellables)

        // Route menu bar actions into the vault browser's relay subjects (spec §9.3–9.4).
        container.menuBarViewModel.onEdit = { [weak self] in
            self?.vaultBrowserVM.openEditSubject.send()
        }
        container.menuBarViewModel.onSave = { [weak self] in
            self?.vaultBrowserVM.saveSubject.send()
        }

        // Forward MenuBarViewModel published state into RootViewModel so the SceneBuilder
        // reacts to changes. @ObservedObject does not trigger App.body re-evaluations —
        // only @StateObject does. RootViewModel is the @StateObject bridge for scene state.
        container.menuBarViewModel.$isVaultUnlocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.menuBarIsVaultUnlocked = v }
            .store(in: &cancellables)
        container.menuBarViewModel.$canEdit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.menuBarCanEdit = v }
            .store(in: &cancellables)
        container.menuBarViewModel.$canSave
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.menuBarCanSave = v }
            .store(in: &cancellables)
    }

    func handleLoginFlow(_ state: LoginFlowState) {
        switch state {
        case .login:       screen = .login
        case .loading:     screen = .loading
        case .totpPrompt:  screen = .totpPrompt
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:
            vaultBrowserVM.handleSyncCompleted(syncedAt: Date())
            container.menuBarViewModel.setVaultUnlocked(true)
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
                try await container.authRepository.signOut()
            } catch {
                logger.error("Sign-out error: \(error.localizedDescription, privacy: .public)")
            }
            unlockVM = nil
            screen   = .login
            logger.info("Sign out completed")
        }
    }

    func handleUnlockFlow(_ state: UnlockFlowState) {
        switch state {
        case .unlock:       screen = .unlock
        case .loading:      screen = .unlock   // stay on unlock screen with spinner
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:
            vaultBrowserVM.handleSyncCompleted(syncedAt: Date())
            container.menuBarViewModel.setVaultUnlocked(true)
            screen = .vault
        case .login:
            // "Sign in with a different account" — reset to login.
            unlockVM = nil
            screen   = .login
        }
        logger.info("Screen transition → \(String(describing: state))")
    }
}
