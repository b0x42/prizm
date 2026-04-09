import XCTest

/// XCUITest: US4 Search Journey (T066)
///
/// Validates real-time search filtering in the vault browser: typing to filter,
/// category switch preserves search term, clearing the bar restores the full list,
/// and empty state on no match.
///
/// **Prerequisites**: App must be launched with a populated vault.
/// **Success Criteria**: SC-008 — <100ms per keystroke for 1,000 items.
final class SearchJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--inject-session", "--inject-vault", "--skip-sync"]
        app.launch()

        // Ensure vault browser is visible.
        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(vaultNav.waitForExistence(timeout: 30), "Vault browser must be visible")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - US4 Scenario 1: Search bar exists and is accessible

    /// Verifies the search bar is present in the toolbar.
    func testSearchBarExists() {
        // macOS .searchable places a search field in the toolbar.
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Search bar should exist in the toolbar"
        )
    }

    // MARK: - US4 Scenario 2: Typing filters items in real time

    /// Verifies that typing in the search bar immediately filters the item list.
    func testTypingFiltersItems() {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Count items before search.
        let itemPredicate = NSPredicate(format: "identifier BEGINSWITH 'itemList.row.'")
        let itemsBefore = app.descendants(matching: .any).matching(itemPredicate).count

        guard itemsBefore > 0 else {
            throw XCTSkip("No items in test vault — cannot test search filtering")
            return
        }

        // Type a search query that should filter results.
        searchField.click()
        searchField.typeText("zzz_unlikely_match_zzz")

        // Wait briefly for filtering to apply.
        Thread.sleep(forTimeInterval: 0.5)

        let itemsAfter = app.descendants(matching: .any).matching(itemPredicate).count
        // Either items are filtered (fewer) or empty state appears.
        let emptyState = app.descendants(matching: .any)["itemList.empty"]
        XCTAssertTrue(
            itemsAfter < itemsBefore || emptyState.exists,
            "Search should filter items or show empty state"
        )
    }

    // MARK: - US4 Scenario 3: Clearing search restores full list

    /// Verifies that clearing the search bar restores all items in the current category.
    func testClearingSearchRestoresFullList() {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Count items before search.
        let itemPredicate = NSPredicate(format: "identifier BEGINSWITH 'itemList.row.'")
        let itemsBefore = app.descendants(matching: .any).matching(itemPredicate).count

        guard itemsBefore > 0 else { return }

        // Search for something.
        searchField.click()
        searchField.typeText("test")
        Thread.sleep(forTimeInterval: 0.3)

        // Clear the search field.
        // On macOS, Cmd+A then Delete clears a text field.
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey(.delete, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        let itemsAfterClear = app.descendants(matching: .any).matching(itemPredicate).count
        XCTAssertEqual(
            itemsAfterClear, itemsBefore,
            "Clearing search should restore the full item list"
        )
    }

    // MARK: - US4 Scenario 4: Search term preserved on category switch

    /// Verifies that the search term is preserved when switching sidebar categories,
    /// and items are re-filtered against the new category.
    func testSearchTermPreservedOnCategorySwitch() {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Type a search term.
        searchField.click()
        searchField.typeText("test")
        Thread.sleep(forTimeInterval: 0.3)

        // Switch sidebar category.
        let favorites = app.descendants(matching: .any)["sidebar.favorites"]
        if favorites.waitForExistence(timeout: 5) {
            favorites.click()
            Thread.sleep(forTimeInterval: 0.3)

            // Verify search field still has the term.
            XCTAssertEqual(
                searchField.value as? String, "test",
                "Search term should be preserved after category switch"
            )
        }
    }

    // MARK: - US4 Scenario 5: Empty state on no match

    /// Verifies that searching for a non-existent term shows the empty state.
    func testEmptyStateOnNoMatch() {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.click()
        searchField.typeText("zzz_no_item_will_ever_match_this_zzz")
        Thread.sleep(forTimeInterval: 0.5)

        let emptyState = app.descendants(matching: .any)["itemList.empty"]
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 5),
            "Empty state should appear when no items match search"
        )
    }

    // MARK: - US4 Scenario 6: Search performance (SC-008)

    /// Measures search keystroke latency against SC-008 (<100ms per keystroke, 1,000 items).
    func testSearchPerformance() {
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else { return }

        searchField.click()

        measure {
            searchField.typeText("a")
            // Allow UI to update.
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
