import Combine
import Foundation
import os.log

// MARK: - MenuBarViewModel

/// ViewModel for the "Item" menu bar extra.
///
/// Observes shared session and edit state to determine:
/// - Whether the vault is unlocked (controls menu bar extra visibility).
/// - Whether the Edit action should be enabled (item selected, sheet closed).
/// - Whether the Save action should be enabled (sheet open, name non-empty, not saving).
///
/// The menu bar extra is only shown when `isVaultUnlocked == true`; it disappears
/// immediately on lock (spec §9.2).
@MainActor
final class MenuBarViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isVaultUnlocked: Bool = false

    // MARK: - Shared state bindings

    /// Reflects whether an item is currently selected and the edit sheet is not open.
    /// Set by `AppContainer` after the vault browser is ready.
    @Published var canEdit: Bool = false

    /// Reflects whether the edit sheet is open, the name is non-empty, and no save is in-flight.
    /// Set by `AppContainer` / `ItemDetailView` after the edit sheet state changes.
    @Published var canSave: Bool = false

    // MARK: - Actions

    /// Triggers the Edit action (opens the edit sheet for the selected item).
    /// Wired by the caller (AppContainer / MacwardenApp).
    var onEdit: (() -> Void)?

    /// Triggers the Save action (saves in-flight edits).
    /// Wired by the caller.
    var onSave: (() -> Void)?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.macwarden", category: "MenuBarViewModel")

    // MARK: - Init

    init() {
        subscribeToVaultLock()
    }

    // MARK: - Vault lock/unlock

    /// Update vault lock state. Called by the outer state machine when the screen changes.
    func setVaultUnlocked(_ unlocked: Bool) {
        isVaultUnlocked = unlocked
        if !unlocked {
            canEdit = false
            canSave = false
        }
    }

    private func subscribeToVaultLock() {
        NotificationCenter.default
            .publisher(for: .vaultDidLock)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setVaultUnlocked(false)
            }
            .store(in: &cancellables)
    }
}
