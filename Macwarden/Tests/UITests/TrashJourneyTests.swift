import XCTest

/// XCUITest: Trash Journey (delete-restore-items)
///
/// Validates the full delete → trash → restore flow and the permanent delete + empty-trash
/// flows through the UI.
///
/// Prerequisites: App launched with `--ui-testing`, `--inject-session`, `--inject-vault`,
/// `--skip-sync` so a pre-populated vault (including at least one active item and one
/// pre-trashed item) is available without a network round-trip.
final class TrashJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--inject-session", "--inject-vault", "--skip-sync"]
        app.launch()

        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(vaultNav.waitForExistence(timeout: 30), "Vault browser must be visible")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 7.1: Soft-delete from list, verify item appears in Trash

    /// Soft-deletes the first item via the list context menu and verifies it appears
    /// in the Trash sidebar selection.
    func testSoftDelete_fromListContextMenu_itemAppearsInTrash() throws {
        let list     = app.tables["itemList.list"]
        let firstRow = list.cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Vault list must have at least one item")

        let itemName = firstRow.staticTexts.firstMatch.label

        // Right-click to open the context menu and choose Delete.
        firstRow.rightClick()
        let deleteMenuItem = app.menuItems["Delete"]
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 3))
        deleteMenuItem.click()

        // Confirm the "Move to Trash?" alert.
        let moveToTrashButton = app.buttons["Move to Trash"]
        XCTAssertTrue(moveToTrashButton.waitForExistence(timeout: 3))
        moveToTrashButton.click()

        // Navigate to Trash.
        let trashSidebarRow = app.buttons["sidebar.trash"]
        XCTAssertTrue(trashSidebarRow.waitForExistence(timeout: 3))
        trashSidebarRow.click()

        // Verify the deleted item now appears in the Trash list.
        let trashedRow = app.tables["itemList.list"].cells.containing(.staticText, identifier: itemName).firstMatch
        XCTAssertTrue(trashedRow.waitForExistence(timeout: 5), "Deleted item should appear in Trash")
    }

    // MARK: - 7.2: Restore from Trash, verify item reappears in active vault

    /// Restores a trashed item via the Trash context menu and verifies it reappears
    /// in the active vault's All Items list.
    func testRestore_fromTrashContextMenu_itemReappearsInActiveVault() throws {
        // Navigate to Trash.
        let trashSidebarRow = app.buttons["sidebar.trash"]
        XCTAssertTrue(trashSidebarRow.waitForExistence(timeout: 5))
        trashSidebarRow.click()

        let trashList = app.tables["itemList.list"]
        let firstTrashed = trashList.cells.firstMatch
        XCTAssertTrue(firstTrashed.waitForExistence(timeout: 5), "Trash must have at least one item")

        let itemName = firstTrashed.staticTexts.firstMatch.label

        // Right-click to open context menu and choose Restore.
        firstTrashed.rightClick()
        let restoreMenuItem = app.menuItems["Restore"]
        XCTAssertTrue(restoreMenuItem.waitForExistence(timeout: 3))
        restoreMenuItem.click()

        // Navigate back to All Items.
        let allItemsRow = app.buttons["sidebar.allItems"]
        XCTAssertTrue(allItemsRow.waitForExistence(timeout: 3))
        allItemsRow.click()

        // Verify the restored item appears in the active vault.
        let restoredRow = app.tables["itemList.list"].cells.containing(.staticText, identifier: itemName).firstMatch
        XCTAssertTrue(restoredRow.waitForExistence(timeout: 5), "Restored item should appear in active vault")
    }

    // MARK: - 7.3: Permanently delete a trashed item

    /// Permanently deletes a trashed item via the context menu and verifies it is
    /// removed from the Trash list entirely.
    func testPermanentDelete_fromTrashContextMenu_itemDisappears() throws {
        // Navigate to Trash.
        let trashSidebarRow = app.buttons["sidebar.trash"]
        XCTAssertTrue(trashSidebarRow.waitForExistence(timeout: 5))
        trashSidebarRow.click()

        let trashList = app.tables["itemList.list"]
        let firstTrashed = trashList.cells.firstMatch
        XCTAssertTrue(firstTrashed.waitForExistence(timeout: 5), "Trash must have at least one item")

        let itemName = firstTrashed.staticTexts.firstMatch.label

        // Right-click → "Delete Permanently".
        firstTrashed.rightClick()
        let permanentDeleteMenuItem = app.menuItems["Delete Permanently"]
        XCTAssertTrue(permanentDeleteMenuItem.waitForExistence(timeout: 3))
        permanentDeleteMenuItem.click()

        // Confirm the destructive alert.
        let confirmButton = app.buttons["Delete Permanently"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.click()

        // Verify the item is gone from Trash.
        let stillPresent = app.tables["itemList.list"].cells.containing(.staticText, identifier: itemName).firstMatch
        XCTAssertFalse(stillPresent.waitForExistence(timeout: 3), "Permanently deleted item should not appear in Trash")
    }

}
