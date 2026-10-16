import AppKit
import SwiftUI

// MARK: - AppVisibility
//
// Why AppKit: FR-011 says codes must stop updating and disappear while the app is hidden or all
// its windows are minimized, but NOT when the window merely loses focus (the user reads a code
// next to the app that needs it). SwiftUI's `scenePhase` is documented in terms of scene
// activity rather than window visibility, so it cannot reliably tell those cases apart on
// macOS. `NSWindow.occlusionState` reports exactly "is any pixel of this window visible", and
// covers ⌘H, minimize, and other Spaces. Recorded in plan.md Complexity Tracking
// (Constitution §I: AppKit only where SwiftUI has no equivalent).

enum AppVisibility {
    /// True when at least one of the app's windows is visible on screen.
    @MainActor
    static var isAnyWindowVisible: Bool {
        NSApp.windows.contains { $0.isVisible && $0.occlusionState.contains(.visible) }
    }
}

private struct AppVisibilityModifier: ViewModifier {
    let onChange: (Bool) -> Void

    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .task {
                // Occlusion changes fire for every window of the app; only publish real changes.
                isVisible = AppVisibility.isAnyWindowVisible
                for await _ in NotificationCenter.default.notifications(
                    named: NSWindow.didChangeOcclusionStateNotification
                ) {
                    let now = AppVisibility.isAnyWindowVisible
                    if now != isVisible { isVisible = now }
                }
            }
            // The action is invoked from `.onChange`, whose closure SwiftUI rebuilds on every
            // render. Calling it from inside the long-lived `.task` above would use the closure
            // captured when the view first appeared, so after the selection changed it would
            // restart the tracker for the OLD item and leave the new item's card on its spinner.
            .onChange(of: isVisible) { _, visible in onChange(visible) }
    }
}

extension View {
    /// Calls `action(true)` when the app becomes visible again and `action(false)` when it is
    /// hidden or all its windows are minimized/occluded. Not called for plain focus changes.
    func onAppVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(AppVisibilityModifier(onChange: action))
    }
}
