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
                viewModel:     rootVM.vaultBrowserVM,
                faviconLoader: container.faviconLoader
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
            screen = .vault
        case .login:
            // "Sign in with a different account" — reset to login.
            unlockVM = nil
            screen   = .login
        }
        logger.info("Screen transition → \(String(describing: state))")
    }
}
