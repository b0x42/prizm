import SwiftUI

// MARK: - MenuBarExtraView

/// Content of the "Item" menu bar extra dropdown.
///
/// Shows two actions — Edit and Save — mirroring the keyboard shortcuts that are
/// also active in the main window. The `.menuBarExtraStyle(.menu)` on the
/// `MenuBarExtra` scene causes SwiftUI to render this as a standard macOS dropdown
/// rather than a popover, so the shortcuts appear in the menu item rows.
///
/// Visibility: only shown when the vault is unlocked (controlled by the parent scene).
struct MenuBarExtraView: View {

    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        // Edit — opens the edit sheet for the selected item (spec §9.3).
        // Disabled when no item is selected or the sheet is already open.
        Button("Edit") {
            viewModel.onEdit?()
        }
        .disabled(!viewModel.canEdit)
        // ⌘E appears in the dropdown row (spec §9.3 "show shortcut in dropdown").
        .keyboardShortcut("e", modifiers: .command)

        // Save — persists in-flight edits (spec §9.4).
        // Disabled when the edit sheet is not open or the draft is invalid.
        Button("Save") {
            viewModel.onSave?()
        }
        .disabled(!viewModel.canSave)
        // ⌘S appears in the dropdown row (spec §9.4 "show shortcut in dropdown").
        .keyboardShortcut("s", modifiers: .command)
    }
}
