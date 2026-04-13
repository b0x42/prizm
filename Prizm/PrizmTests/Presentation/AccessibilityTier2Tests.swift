import XCTest
import SwiftUI
@testable import Prizm

@MainActor
final class AccessibilityTier2Tests: XCTestCase {

    // MARK: - 7.1 ContrastAwareOpacity

    func testOpacity_bannerBackground_increasedIsHigher() {
        XCTAssertGreaterThan(
            Opacity.bannerBackground(.increased),
            Opacity.bannerBackground(.standard)
        )
    }

    func testOpacity_cardBorder_increasedIsHigher() {
        XCTAssertGreaterThan(
            Opacity.cardBorder(.increased),
            Opacity.cardBorder(.standard)
        )
    }

    func testOpacity_trashBanner_increasedIsHigher() {
        XCTAssertGreaterThan(
            Opacity.trashBanner(.increased),
            Opacity.trashBanner(.standard)
        )
    }

    func testOpacity_errorBanner_increasedIsHigher() {
        XCTAssertGreaterThan(
            Opacity.errorBanner(.increased),
            Opacity.errorBanner(.standard)
        )
    }

    func testOpacity_dropTarget_increasedIsHigher() {
        XCTAssertGreaterThan(
            Opacity.dropTarget(.increased),
            Opacity.dropTarget(.standard)
        )
    }

    // MARK: - 7.2 optionalAnimation

    func testOptionalAnimation_executesBody() {
        var executed = false
        optionalAnimation(.default) { executed = true }
        XCTAssertTrue(executed)
    }

    // MARK: - 7.3 Error strings include suggestions

    func testAuthError_invalidURL_includesHTTPS() {
        let msg = AuthError.invalidURL.errorDescription ?? ""
        XCTAssertTrue(msg.contains("https://"), "Should suggest including https://")
    }

    func testAuthError_invalidCredentials_includesSuggestion() {
        let msg = AuthError.invalidCredentials.errorDescription ?? ""
        XCTAssertTrue(msg.contains("Check your email"), "Should suggest checking credentials")
    }

    func testAuthError_serverUnreachable_includesSuggestion() {
        let msg = AuthError.serverUnreachable.errorDescription ?? ""
        XCTAssertTrue(msg.contains("Verify the URL"), "Should suggest verifying URL")
    }

    func testAuthError_networkUnavailable_includesSuggestion() {
        let msg = AuthError.networkUnavailable.errorDescription ?? ""
        XCTAssertTrue(msg.contains("Check your network"), "Should suggest checking network")
    }

    func testSyncError_unauthorized_includesSuggestion() {
        let msg = SyncError.unauthorized.errorDescription ?? ""
        XCTAssertTrue(msg.contains("signing out"), "Should suggest signing out and in")
    }

    func testSyncError_networkUnavailable_includesSuggestion() {
        let msg = SyncError.networkUnavailable.errorDescription ?? ""
        XCTAssertTrue(msg.contains("Check your network"), "Should suggest checking network")
    }

    func testSyncError_serverUnreachable_includesSuggestion() {
        let url = URL(string: "https://example.com")!
        let msg = SyncError.serverUnreachable(url).errorDescription ?? ""
        XCTAssertTrue(msg.contains("Verify the URL"), "Should suggest verifying URL")
    }
}
