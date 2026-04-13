import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import SwiftUI

/// An `NSViewRepresentable` wrapper for `LAAuthenticationView`.
///
/// This view is entirely passive — it contains no delegate or callbacks. Its sole
/// purpose is to be paired with an `LAContext` before `evaluatePolicy` is called.
/// Once paired, any `evaluatePolicy` call on that context routes its UI through
/// this view rather than showing the standard system modal dialog.
///
/// The caller is responsible for calling `evaluatePolicy` on the same `LAContext`
/// after this view is rendered (e.g. via `.task(id:)`). Results are delivered via
/// the normal `evaluatePolicy` completion handler.
///
/// Re-arming: use `.id(version)` on this view and supply a new `LAContext` when
/// the version changes. SwiftUI will recreate `LAAuthenticationView` with the new
/// context, ready for the next `evaluatePolicy` call.
struct EmbeddedTouchIDView: NSViewRepresentable {

    let context: LAContext

    func makeNSView(context: Context) -> LAAuthenticationView {
        LAAuthenticationView(context: self.context, controlSize: .regular)
    }

    func updateNSView(_ nsView: LAAuthenticationView, context: Context) {}
}
