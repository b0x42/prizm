import SwiftUI

/// Applies `withAnimation` only when Reduce Motion is not enabled.
/// When Reduce Motion is active, the body executes immediately without animation.
func optionalAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    if AccessibilityInfo.prefersReducedMotion {
        return try body()
    } else {
        return try withAnimation(animation) {
            try body()
        }
    }
}

/// Reads the current Reduce Motion preference from the accessibility system.
enum AccessibilityInfo {
    static var prefersReducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
