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

/// Set to `true` by a floating layer (e.g. the search suggestions dropdown) so views
/// underneath it stop reacting to `onHover`.
///
/// On macOS, `onHover` is not occluded by views drawn on top, so a hover over the
/// dropdown also highlights the list row or field beneath it. Disabling hit testing on
/// the whole split view would fix that too, but toggling `allowsHitTesting` on a subtree
/// hosting AppKit-backed views (`List`, `HSplitView`) re-hosts them and shifted the
/// item list under the sidebar. Suppressing hover through the environment is layout-neutral.
struct HoverSuppressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isHoverSuppressed: Bool {
        get { self[HoverSuppressedKey.self] }
        set { self[HoverSuppressedKey.self] = newValue }
    }
}

/// Reads the current Reduce Motion preference from the accessibility system.
enum AccessibilityInfo {
    static var prefersReducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
