import SwiftUI

/// Provides contrast-aware opacity values that increase when the user enables
/// "Increase contrast" in System Settings → Accessibility → Display.
///
/// Usage:
/// ```swift
/// @Environment(\.colorSchemeContrast) private var contrast
/// // ...
/// .background(Color.yellow.opacity(Opacity.bannerBackground(contrast)))
/// ```
enum Opacity {
    static func bannerBackground(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.5 : 0.35
    }

    static func cardBorder(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.2 : 0.12
    }

    static func trashBanner(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.3 : 0.2
    }

    static func errorBanner(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.3 : 0.2
    }

    static func dropTarget(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.4 : 0.25
    }
}
