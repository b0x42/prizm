import Foundation

/// Centralized accessibility identifiers used by SwiftUI views and XCUITests.
///
/// Keeping identifiers in a single namespace avoids typos and makes refactoring safer.
/// Both the main app target and the UI test target reference this enum.
nonisolated enum AccessibilityID {

    // MARK: - Login (US1)

    enum Login {
        static let serverURLField    = "login.serverURL"
        static let emailField        = "login.email"
        static let passwordField     = "login.password"
        static let signInButton      = "login.signIn"
        static let errorMessage      = "login.error"
        static let headerTitle       = "login.headerTitle"
    }

    // MARK: - TOTP (US1)

    enum TOTP {
        static let codeField         = "totp.code"
        static let rememberToggle    = "totp.remember"
        static let continueButton    = "totp.continue"
        static let cancelButton      = "totp.cancel"
        static let errorMessage      = "totp.error"
        static let headerTitle       = "totp.headerTitle"
    }

    // MARK: - Sync Progress

    enum Sync {
        static let progressMessage   = "sync.progressMessage"
    }

    // MARK: - Unlock (US2)

    enum Unlock {
        static let emailLabel        = "unlock.email"
        static let passwordField     = "unlock.password"
        static let unlockButton      = "unlock.unlock"
        static let errorMessage      = "unlock.error"
        static let headerTitle       = "unlock.headerTitle"
        static let switchAccount     = "unlock.switchAccount"
    }

    // MARK: - Vault Browser (US3)

    enum Vault {
        static let navigationSplit   = "vault.navigationSplit"
        static let searchField       = "vault.search"
        static let lastSyncedLabel   = "vault.lastSynced"
        static let syncStatusLabel   = "vault.syncStatus"
        static let syncErrorBanner   = "vault.syncErrorBanner"
        static let syncErrorDismiss  = "vault.syncErrorDismiss"
    }

    // MARK: - Sidebar (US3)

    enum Sidebar {
        static let list              = "sidebar.list"
        static let allItems          = "sidebar.allItems"
        static let favorites         = "sidebar.favorites"
        static let trash             = "sidebar.trash"
        static func type(_ name: String) -> String { "sidebar.type.\(name)" }
    }

    // MARK: - Item List (US3)

    enum ItemList {
        static let list              = "itemList.list"
        static let emptyState        = "itemList.empty"
        static func row(_ id: String) -> String { "itemList.row.\(id)" }
    }

    // MARK: - Item Detail (US3)

    enum Detail {
        static let emptyState        = "detail.empty"
        static let itemName          = "detail.name"
        static let createdDate       = "detail.created"
        static let updatedDate       = "detail.updated"
        /// Accessibility identifier for a `DetailSectionCard` header label.
        static func cardHeader(_ title: String) -> String {
            "detail.cardHeader.\(title.lowercased().replacingOccurrences(of: " ", with: "."))"
        }
    }

    // MARK: - Field Row (US3)

    enum Field {
        static func row(_ label: String) -> String { "field.\(label)" }
        static func copyButton(_ label: String) -> String { "field.\(label).copy" }
        static func revealButton(_ label: String) -> String { "field.\(label).reveal" }
        static func openButton(_ label: String) -> String { "field.\(label).open" }
    }

    // MARK: - Masked Field (US3)

    enum Masked {
        static func value(_ label: String) -> String { "masked.\(label).value" }
        static func toggle(_ label: String) -> String { "masked.\(label).toggle" }
    }

    // MARK: - Item Edit (edit-vault-items)

    enum Edit {
        /// The "Edit" toolbar button in ItemDetailView.
        static let editButton    = "edit.button.edit"
        /// The "Save" / "Saving…" button in ItemEditView.
        static let saveButton    = "edit.button.save"
        /// The "Discard" button in ItemEditView.
        static let discardButton = "edit.button.discard"
        /// The inline error banner shown on save failure.
        static let errorBanner   = "edit.errorBanner"
    }

    // MARK: - Trash (delete-restore-items)

    enum Trash {
        /// The empty-state view shown when Trash contains no items.
        static let emptyState        = "trash.emptyState"
        /// The banner shown in ItemDetailView when the selected item is in trash.
        static let statusBanner      = "trash.statusBanner"
        /// The "Restore" toolbar button in ItemDetailView for trashed items.
        static let restoreButton     = "trash.button.restore"
        /// The "Delete Permanently" toolbar button in ItemDetailView for trashed items.
        static let permanentDeleteButton = "trash.button.permanentDelete"
    }

    // MARK: - Create Item (add-vault-items)

    enum Create {
        /// The "+" button that opens the new-item type picker popover.
        static let newItemButton = "create.button.newItem"
        /// The List inside the type picker popover.
        static let pickerList    = "typePicker.list"
        /// A row inside the type picker; `typeName` is the `ItemType.rawValue` (e.g. "login", "card").
        static func pickerRow(_ typeName: String) -> String { "typePicker.row.\(typeName)" }
    }

    // MARK: - Password Generator (password-generator)

    enum Generator {
        static let modePicker          = "generator.modePicker"
        static let lengthSlider        = "generator.lengthSlider"
        static let uppercaseToggle     = "generator.toggle.uppercase"
        static let lowercaseToggle     = "generator.toggle.lowercase"
        static let digitsToggle        = "generator.toggle.digits"
        static let symbolsToggle       = "generator.toggle.symbols"
        static let avoidAmbiguousToggle = "generator.toggle.avoidAmbiguous"
        static let wordCountStepper    = "generator.wordCount"
        static let separatorField      = "generator.separator"
        static let capitalizeToggle    = "generator.toggle.capitalize"
        static let includeNumberToggle = "generator.toggle.includeNumber"
        static let preview             = "generator.preview"
        static let refreshButton       = "generator.button.refresh"
        static let copyButton          = "generator.button.copy"
        static let useButton           = "generator.button.use"
        static let triggerButton       = "generator.button.trigger"
    }
}
