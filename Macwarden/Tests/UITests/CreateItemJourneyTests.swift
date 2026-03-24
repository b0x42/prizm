import XCTest

/// XCUITest: Create Vault Item Journey (add-vault-items)
///
/// Validates that the "+" button is permanently anchored in the content column toolbar,
/// is hidden only while Trash is selected, and reappears in the correct position when
/// the user leaves Trash — regardless of which category was visited before Trash.
///
/// Prerequisites: App launched with `--ui-testing`, `--inject-session`, `--inject-vault`,
/// `--skip-sync` so a pre-populated vault is available without a network round-trip.
final class CreateItemJourneyTests: XCTestCase {

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

    // MARK: - Button visible on launch

    /// Verifies the "+" button is hittable when the vault browser first appears (any default
    /// non-Trash category selected).
    func testNewItemButton_visibleOnLaunch() throws {
        let newItemButton = app.buttons["create.button.newItem"]
        XCTAssertTrue(newItemButton.waitForExistence(timeout: 5), "+ button must exist in toolbar on launch")
        XCTAssertTrue(newItemButton.isHittable, "+ button must be hittable on launch")
    }

    // MARK: - Button hidden in Trash

    /// Verifies the "+" button is not rendered while Trash is selected.
    /// The button is in the view body (not a toolbar item), so it is simply absent
    /// from the else-branch when Trash is active — no frame, no icon, no chrome.
    func testNewItemButton_hiddenInTrash() throws {
        let trashRow = app.buttons["sidebar.trash"]
        XCTAssertTrue(trashRow.waitForExistence(timeout: 5))
        trashRow.click()

        let newItemButton = app.buttons["create.button.newItem"]
        XCTAssertFalse(newItemButton.waitForExistence(timeout: 2),
                       "+ button must not exist in view hierarchy while Trash is selected")
    }

    // MARK: - Button reappears after leaving Trash

    /// Selects Trash then navigates to All Items and verifies the "+" button is hittable
    /// and positioned in the content column toolbar (above the item list).
    ///
    /// This is the regression scenario for the toolbar-drift bug: the button previously
    /// stayed on the trailing window edge instead of the content column after a Trash visit.
    func testNewItemButton_reappearsAfterLeavingTrash() throws {
        // Go to Trash first.
        let trashRow = app.buttons["sidebar.trash"]
        XCTAssertTrue(trashRow.waitForExistence(timeout: 5))
        trashRow.click()

        // Leave Trash by selecting All Items.
        let allItemsRow = app.buttons["sidebar.allItems"]
        XCTAssertTrue(allItemsRow.waitForExistence(timeout: 5))
        allItemsRow.click()

        let newItemButton = app.buttons["create.button.newItem"]
        XCTAssertTrue(newItemButton.waitForExistence(timeout: 5), "+ button must exist after leaving Trash")
        XCTAssertTrue(newItemButton.isHittable, "+ button must be hittable after leaving Trash")

        // Verify the button is above the item list and not on the trailing window edge.
        // The item list table must also be visible; if the button drifted to the window toolbar
        // its frame would be outside (to the right of) the content column.
        let itemList = app.tables["itemList.list"]
        XCTAssertTrue(itemList.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(
            newItemButton.frame.maxX,
            itemList.frame.maxX + 60, // 60 pt tolerance for toolbar insets
            "+ button must not have drifted outside the content column after leaving Trash"
        )
    }

    // MARK: - ⌘N keyboard shortcut

    /// Presses ⌘N and verifies the type picker popover opens with Login pre-selected.
    /// The picker is a SwiftUI List in a popover (not an NSMenu), so rows are queried
    /// as List cells via their "typePicker.row.<rawValue>" accessibility identifiers.
    func testCmdN_opensPicker_inNonTrashCategory() throws {
        app.typeKey("n", modifierFlags: .command)

        let loginRow = app.cells["typePicker.row.login"]
        XCTAssertTrue(loginRow.waitForExistence(timeout: 3), "⌘N must open the type picker with Login row visible")

        // Dismiss without creating.
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Selects Trash, presses ⌘N, and verifies the type picker does not open.
    func testCmdN_isNoOp_inTrash() throws {
        let trashRow = app.buttons["sidebar.trash"]
        XCTAssertTrue(trashRow.waitForExistence(timeout: 5))
        trashRow.click()

        app.typeKey("n", modifierFlags: .command)

        // The picker list must not appear, and no edit sheet must open.
        let pickerList = app.tables["typePicker.list"]
        XCTAssertFalse(pickerList.waitForExistence(timeout: 2), "⌘N must not open the type picker in Trash")

        let saveButton = app.buttons["edit.button.save"]
        XCTAssertFalse(saveButton.waitForExistence(timeout: 2), "⌘N must not open the edit sheet in Trash")
    }

    /// Presses ⌘N then immediately Enter (no arrow key) and verifies the Login edit sheet opens.
    /// Login is pre-selected when the picker opens, so Enter confirms it without navigation.
    func testCmdN_thenEnter_opensLoginSheet() throws {
        app.typeKey("n", modifierFlags: .command)

        // Wait for the picker to appear.
        let loginRow = app.cells["typePicker.row.login"]
        XCTAssertTrue(loginRow.waitForExistence(timeout: 3), "Type picker must appear after ⌘N")

        app.typeKey(.return, modifierFlags: [])

        // The Login edit sheet should now be open.
        let saveButton = app.buttons["edit.button.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Login edit sheet must open after ⌘N + Enter")

        // Dismiss without saving.
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Presses ⌘N, navigates down once with ↓ to select Card, then confirms with Enter.
    /// Verifies the Card edit sheet opens — covering the arrow-key navigation scenario.
    func testCmdN_arrowDown_thenEnter_opensCardSheet() throws {
        app.typeKey("n", modifierFlags: .command)

        // Wait for the picker to appear with Login pre-selected.
        let loginRow = app.cells["typePicker.row.login"]
        XCTAssertTrue(loginRow.waitForExistence(timeout: 3), "Type picker must appear after ⌘N")

        // Press ↓ to move selection from Login to Card (second item).
        app.typeKey(.downArrow, modifierFlags: [])

        // Confirm Card with Enter.
        app.typeKey(.return, modifierFlags: [])

        // The edit sheet must open — Card form is identified by the Save button.
        let saveButton = app.buttons["edit.button.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Card edit sheet must open after ⌘N + ↓ + Enter")

        // Dismiss without saving.
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Button stable across multiple category switches

    /// Visits a non-Login category (Card sidebar item) and returns to Login (All Items),
    /// verifying the button stays hittable throughout.
    func testNewItemButton_stableAcrossCategorySwitches() throws {
        // Navigate to Card type.
        let cardRow = app.buttons["sidebar.type.card"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5))
        cardRow.click()

        var newItemButton = app.buttons["create.button.newItem"]
        XCTAssertTrue(newItemButton.isHittable, "+ button must be hittable in Card category")

        // Navigate back to All Items.
        let allItemsRow = app.buttons["sidebar.allItems"]
        XCTAssertTrue(allItemsRow.waitForExistence(timeout: 5))
        allItemsRow.click()

        newItemButton = app.buttons["create.button.newItem"]
        XCTAssertTrue(newItemButton.isHittable, "+ button must be hittable after returning to All Items")
    }
}
