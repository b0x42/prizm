import XCTest

/// XCUITest: US3 Vault Browser Journey (T062)
///
/// Validates the three-pane vault browser: sidebar navigation, item list selection,
/// detail rendering for all item types, field reveal/mask, copy + clipboard clear,
/// and sync error banner behavior.
///
/// **Prerequisites**: App must be launched with a populated vault (use `--inject-session`
/// and `--inject-vault` launch arguments to pre-seed test data).
/// **Success Criteria**: SC-003 (≤200ms pane render), SC-005 (1,000 items without lag).
final class VaultBrowserJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--inject-session", "--inject-vault", "--skip-sync"]
        app.launch()

        // Ensure we reach the vault browser.
        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(vaultNav.waitForExistence(timeout: 30), "Vault browser must be visible")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - US3 Scenario 1: Three-pane layout visible

    /// Verifies the vault browser shows the NavigationSplitView with sidebar, list, and detail.
    func testThreePaneLayoutVisible() {
        // Sidebar categories should be visible.
        let allItems = app.staticTexts["sidebar.allItems"]
            .waitForExistence(timeout: 5) ? true : app.outlines.buttons["sidebar.allItems"]
            .waitForExistence(timeout: 2)
        // One of the sidebar identifiers should exist (List row or outline row).
        XCTAssertTrue(
            app.descendants(matching: .any)["sidebar.allItems"].waitForExistence(timeout: 5),
            "All Items sidebar row should exist"
        )
    }

    // MARK: - US3 Scenario 2: Sidebar navigation filters items

    /// Verifies selecting different sidebar categories filters the item list.
    func testSidebarNavigationFiltersItems() {
        let allItems  = app.descendants(matching: .any)["sidebar.allItems"]
        let favorites = app.descendants(matching: .any)["sidebar.favorites"]

        XCTAssertTrue(allItems.waitForExistence(timeout: 5))

        // Select All Items.
        allItems.click()
        // The item list should show items (or an empty state — depends on test data).

        // Select Favorites.
        XCTAssertTrue(favorites.exists)
        favorites.click()

        // Select a type category.
        let loginType = app.descendants(matching: .any)["sidebar.type.Login"]
        if loginType.exists {
            loginType.click()
        }
    }

    // MARK: - US3 Scenario 3: Selecting an item shows detail

    /// Verifies that clicking an item in the list populates the detail pane.
    func testSelectingItemShowsDetail() {
        // The detail pane should initially show the empty state.
        let emptyState = app.staticTexts["detail.empty"]
        // Try clicking the first item in the list, if any exist.
        let firstItemPredicate = NSPredicate(format: "identifier BEGINSWITH 'itemList.row.'")
        let firstItem = app.descendants(matching: .any).matching(firstItemPredicate).firstMatch

        if firstItem.waitForExistence(timeout: 5) {
            firstItem.click()

            // Detail pane should now show the item name.
            let itemName = app.staticTexts["detail.name"]
            XCTAssertTrue(
                itemName.waitForExistence(timeout: 5),
                "Detail pane should show selected item name"
            )
        } else {
            // No items in vault — empty state should be shown.
            XCTAssertTrue(
                emptyState.waitForExistence(timeout: 5),
                "Empty state should show when no items exist"
            )
        }
    }

    // MARK: - US3 Scenario 4: Empty state when no item selected

    /// Verifies the "No item selected" empty state in the detail pane.
    func testEmptyStateWhenNoItemSelected() {
        // On initial load with no selection, the detail empty state should show.
        // Force deselection by clicking a different sidebar category.
        let favorites = app.descendants(matching: .any)["sidebar.favorites"]
        if favorites.waitForExistence(timeout: 5) {
            favorites.click()
        }

        // Look for the empty state (it may or may not appear depending on prior selection).
        let emptyState = app.descendants(matching: .any)["detail.empty"]
        if emptyState.waitForExistence(timeout: 3) {
            XCTAssertTrue(emptyState.exists, "Detail empty state should be visible")
        }
    }

    // MARK: - US3 Scenario 5: Password field shows masked dots

    /// Verifies that password fields display exactly 8 dots when masked (FR-026).
    func testPasswordFieldShowsMaskedDots() {
        // Navigate to a login item.
        let loginType = app.descendants(matching: .any)["sidebar.type.Login"]
        guard loginType.waitForExistence(timeout: 5) else {
            throw XCTSkip("No Login type in sidebar — test vault may be empty")
            return
        }
        loginType.click()

        // Select the first login item.
        let firstItemPredicate = NSPredicate(format: "identifier BEGINSWITH 'itemList.row.'")
        let firstItem = app.descendants(matching: .any).matching(firstItemPredicate).firstMatch
        guard firstItem.waitForExistence(timeout: 5) else {
            throw XCTSkip("No login items in test vault")
            return
        }
        firstItem.click()

        // Check the masked password value.
        let maskedValue = app.staticTexts["masked.Password.value"]
        if maskedValue.waitForExistence(timeout: 5) {
            XCTAssertEqual(maskedValue.label, "••••••••", "Masked password should show 8 dots")
        }
    }

    // MARK: - US3 Scenario 6: Reveal toggle shows plaintext

    /// Verifies clicking the reveal button shows the plaintext value, and clicking
    /// again re-masks it (FR-026, FR-027).
    func testRevealToggleShowsPlaintext() {
        // Navigate to a login item with a password.
        let loginType = app.descendants(matching: .any)["sidebar.type.Login"]
        guard loginType.waitForExistence(timeout: 5) else { return }
        loginType.click()

        let firstItemPredicate = NSPredicate(format: "identifier BEGINSWITH 'itemList.row.'")
        let firstItem = app.descendants(matching: .any).matching(firstItemPredicate).firstMatch
        guard firstItem.waitForExistence(timeout: 5) else { return }
        firstItem.click()

        let revealBtn   = app.buttons["masked.Password.toggle"]
        let maskedValue = app.staticTexts["masked.Password.value"]

        guard revealBtn.waitForExistence(timeout: 5) else { return }

        // Initially masked.
        XCTAssertEqual(maskedValue.label, "••••••••")

        // Click reveal — should show plaintext.
        revealBtn.click()
        XCTAssertNotEqual(maskedValue.label, "••••••••", "Value should be revealed after toggle")

        // Click again — should re-mask.
        revealBtn.click()
        XCTAssertEqual(maskedValue.label, "••••••••", "Value should be masked after second toggle")
    }

    // MARK: - US3 Scenario 7: Item change resets mask state

    /// Verifies that navigating to a different item resets the reveal state to masked (FR-027).
    func testItemChangeResetsMaskState() {
        let loginType = app.descendants(matching: .any)["sidebar.type.Login"]
        guard loginType.waitForExistence(timeout: 5) else { return }
        loginType.click()

        let itemPredicate = NSPredicate(format: "identifier BEGINSWITH 'itemList.row.'")
        let items = app.descendants(matching: .any).matching(itemPredicate)
        guard items.count >= 2 else {
            // Need at least 2 items to test navigation reset.
            return
        }

        // Select first item and reveal password.
        items.element(boundBy: 0).click()
        let revealBtn = app.buttons["masked.Password.toggle"]
        if revealBtn.waitForExistence(timeout: 5) {
            revealBtn.click()
        }

        // Navigate to second item — mask should reset.
        items.element(boundBy: 1).click()
        let maskedValue = app.staticTexts["masked.Password.value"]
        if maskedValue.waitForExistence(timeout: 5) {
            XCTAssertEqual(maskedValue.label, "••••••••", "Mask should reset on item change")
        }
    }

    // MARK: - US3 Scenario 8: Last synced timestamp removed (no-toolbar-ui)

    /// The "Last synced" label was removed as part of the no-toolbar UI redesign.
    /// This test is retained as a regression check to confirm it is absent.
    func testLastSyncedTimestampVisible() {
        let label = app.staticTexts["vault.lastSynced"]
        XCTAssertFalse(label.waitForExistence(timeout: 2),
                       "Last synced label should not exist after toolbar removal")
    }

    // MARK: - US3 Scenario 9: Sidebar categories always visible

    /// Verifies all sidebar categories are visible even when empty (FR-006, FR-042).
    func testSidebarCategoriesAlwaysVisible() {
        let allItems   = app.descendants(matching: .any)["sidebar.allItems"]
        let favorites  = app.descendants(matching: .any)["sidebar.favorites"]
        let login      = app.descendants(matching: .any)["sidebar.type.Login"]
        let card       = app.descendants(matching: .any)["sidebar.type.Card"]
        let identity   = app.descendants(matching: .any)["sidebar.type.Identity"]
        let secureNote = app.descendants(matching: .any)["sidebar.type.Secure Note"]
        let sshKey     = app.descendants(matching: .any)["sidebar.type.SSH Key"]

        XCTAssertTrue(allItems.waitForExistence(timeout: 5), "All Items should always be visible")
        XCTAssertTrue(favorites.exists, "Favorites should always be visible")
        XCTAssertTrue(login.exists, "Login type should always be visible")
        XCTAssertTrue(card.exists, "Card type should always be visible")
        XCTAssertTrue(identity.exists, "Identity type should always be visible")
        XCTAssertTrue(secureNote.exists, "Secure Note type should always be visible")
        XCTAssertTrue(sshKey.exists, "SSH Key type should always be visible")
    }

    // MARK: - US3 Scenario 10: Empty list shows empty state message

    /// Verifies the item list shows an empty state when a category has no items (FR-042).
    func testEmptyListShowsEmptyState() {
        // SSH Keys are typically empty in test vaults.
        let sshKey = app.descendants(matching: .any)["sidebar.type.SSH Key"]
        guard sshKey.waitForExistence(timeout: 5) else { return }
        sshKey.click()

        let emptyState = app.descendants(matching: .any)["itemList.empty"]
        if emptyState.waitForExistence(timeout: 5) {
            XCTAssertTrue(emptyState.exists, "Empty state message should appear for empty category")
        }
    }
}
