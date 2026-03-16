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
    @StateObject private var loginVM:   LoginViewModel

    init() {
        let c = AppContainer()
        _container = StateObject(wrappedValue: c)
        _loginVM   = StateObject(wrappedValue: c.makeLoginViewModel())
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
        switch loginVM.flowState {
        case .login:
            LoginView(viewModel: loginVM)

        case .loading:
            ProgressView("Signing in…")
                .frame(minWidth: 480, minHeight: 360)

        case .totpPrompt:
            TOTPPromptView(viewModel: loginVM)

        case .syncing(let message):
            SyncProgressView(message: message)

        case .vault:
            // Vault browser implemented in Phase 6.
            VStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Vault unlocked")
                    .font(.title.bold())
                Text("Vault browser coming in Phase 6.")
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 480, minHeight: 360)
        }
    }
}
