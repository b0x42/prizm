//
//  Bitwarden_MacOSApp.swift
//  Bitwarden MacOS
//
//  Created by Benjamin on 15.03.26.
//

import SwiftUI

@main
struct Bitwarden_MacOSApp: App {

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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }

    @ViewBuilder
    private var rootView: some View {
        switch rootVM.screen {
        case .login:
            LoginView(viewModel: rootVM.loginVM)
                .onChange(of: rootVM.loginVM.flowState) { _, state in
                    rootVM.handleLoginFlow(state)
                }

        case .loading:
            ProgressView("Signing in…")
                .frame(minWidth: 480, minHeight: 360)

        case .totpPrompt:
            TOTPPromptView(viewModel: rootVM.loginVM)
                .onChange(of: rootVM.loginVM.flowState) { _, state in
                    rootVM.handleLoginFlow(state)
                }

        case .unlock:
            if let unlockVM = rootVM.unlockVM {
                UnlockView(viewModel: unlockVM)
                    .onChange(of: unlockVM.flowState) { _, state in
                        rootVM.handleUnlockFlow(state)
                    }
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

    let loginVM:         LoginViewModel
    var unlockVM:        UnlockViewModel?
    let vaultBrowserVM:  VaultBrowserViewModel

    private let container: AppContainer

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
    }

    func handleLoginFlow(_ state: LoginFlowState) {
        switch state {
        case .login:       screen = .login
        case .loading:     screen = .loading
        case .totpPrompt:  screen = .totpPrompt
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:       screen = .vault
        }
    }

    func handleUnlockFlow(_ state: UnlockFlowState) {
        switch state {
        case .unlock:       screen = .unlock
        case .loading:      screen = .unlock   // stay on unlock screen with spinner
        case .syncing(let msg): screen = .syncing(message: msg)
        case .vault:        screen = .vault
        case .login:
            // "Sign in with a different account" — reset to login.
            unlockVM = nil
            screen   = .login
        }
    }
}
