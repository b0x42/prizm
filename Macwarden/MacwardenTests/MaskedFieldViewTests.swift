import XCTest
@testable import Macwarden

// MARK: - MaskedFieldViewTests (T045)

/// Unit tests for the `MaskedFieldView` display logic.
///
/// SwiftUI views cannot be instantiated directly in XCTest without a host app or ViewInspector.
/// These tests therefore target the observable state contract via `MaskedFieldState` — a small,
/// testable value type that `MaskedFieldView` owns as `@State`.
///
/// Acceptance criteria (FR-026, FR-027):
///   - Masked state always renders exactly 8 bullet characters ("••••••••")
///   - Toggling reveal shows plaintext; toggling again re-masks
///   - When the bound item identity changes, isRevealed resets to false
final class MaskedFieldViewTests: XCTestCase {

    // MARK: - Masked placeholder

    /// The masked placeholder is exactly 8 bullet dots regardless of actual field length.
    func testMaskedPlaceholder_isEightBullets() {
        let mask = MaskedFieldState.maskedPlaceholder
        XCTAssertEqual(mask, "••••••••")
        XCTAssertEqual(mask.count, 8)
    }

    // MARK: - Display value

    /// When isRevealed == false, displayValue returns the 8-dot placeholder.
    func testDisplayValue_masked_returnsPlaceholder() {
        let state = MaskedFieldState(value: "super-secret-password", isRevealed: false)
        XCTAssertEqual(state.displayValue, MaskedFieldState.maskedPlaceholder)
    }

    /// When isRevealed == true, displayValue returns the actual value.
    func testDisplayValue_revealed_returnsPlaintext() {
        let state = MaskedFieldState(value: "super-secret-password", isRevealed: true)
        XCTAssertEqual(state.displayValue, "super-secret-password")
    }

    /// displayValue with an empty value still returns placeholder when masked.
    func testDisplayValue_emptyValue_maskedReturnsDots() {
        let state = MaskedFieldState(value: "", isRevealed: false)
        XCTAssertEqual(state.displayValue, MaskedFieldState.maskedPlaceholder)
    }

    // MARK: - Toggle reveal

    /// toggled() flips isRevealed from false to true.
    func testToggled_fromMasked_reveals() {
        let state   = MaskedFieldState(value: "secret", isRevealed: false)
        let toggled = state.toggled()
        XCTAssertTrue(toggled.isRevealed)
        XCTAssertEqual(toggled.value, "secret")
    }

    /// toggled() flips isRevealed from true back to false.
    func testToggled_fromRevealed_masks() {
        let state   = MaskedFieldState(value: "secret", isRevealed: true)
        let toggled = state.toggled()
        XCTAssertFalse(toggled.isRevealed)
    }

    // MARK: - Item-change reset (FR-027)

    /// resetForNewItem() returns a new state with isRevealed == false, preserving value.
    func testResetForNewItem_setsRevealedFalse() {
        let state = MaskedFieldState(value: "revealed-value", isRevealed: true)
        let reset = state.resetForNewItem(value: "new-value")
        XCTAssertFalse(reset.isRevealed)
        XCTAssertEqual(reset.value, "new-value")
    }

    /// resetForNewItem() does nothing visible if already masked.
    func testResetForNewItem_alreadyMasked_staysMasked() {
        let state = MaskedFieldState(value: "old", isRevealed: false)
        let reset = state.resetForNewItem(value: "new")
        XCTAssertFalse(reset.isRevealed)
        XCTAssertEqual(reset.value, "new")
    }
}
