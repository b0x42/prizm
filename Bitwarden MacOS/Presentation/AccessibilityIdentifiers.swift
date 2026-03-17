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
        static let syncErrorBanner   = "vault.syncErrorBanner"
        static let syncErrorDismiss  = "vault.syncErrorDismiss"
    }

    // MARK: - Sidebar (US3)

    enum Sidebar {
        static let list              = "sidebar.list"
        static let allItems          = "sidebar.allItems"
        static let favorites         = "sidebar.favorites"
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
}
