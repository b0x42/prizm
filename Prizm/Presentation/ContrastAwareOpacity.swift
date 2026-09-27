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

    static func fieldHover(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.16 : 0.08
    }

    static func contextPickerBorder(_ contrast: ColorSchemeContrast, isHovered: Bool) -> Double {
        if isHovered {
            return contrast == .increased ? 1 : 0.8
        }
        return contrast == .increased ? 0.5 : 0.28
    }

    static func editingBanner(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.35 : 0.2
    }

    static func searchStatusBackground(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.38 : 0.24
    }

    static func itemRowHover(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.16 : 0.08
    }

}
