import Foundation

// MARK: - TempFileManaging

/// Protocol for managing the lifecycle of temporary files written during attachment open.
///
/// Placed in the Presentation layer (not Domain) because it is an infrastructure concern
/// driven by UI lifecycle events — not a business rule. `AttachmentRowViewModel` depends
/// on `any TempFileManaging` so it never imports the App-layer concrete type directly,
/// keeping the Presentation layer clean (Constitution §II).
///
/// The concrete implementation `AttachmentTempFileManager` lives in the App layer,
/// which may import AppKit to register for `NSApplication.didBecomeActiveNotification`.
protocol TempFileManaging: AnyObject, Sendable {

    /// Records `url` with a 30-second deletion deadline.
    ///
    /// The file will be zeroed and deleted by `cleanup()` once its deadline passes.
    func register(url: URL)

    /// Zeroes and deletes all registered files whose deletion deadline has passed.
    ///
    /// Called on each foreground transition and by a scheduled background task spawned
    /// by `AttachmentRowViewModel` 30 seconds after `register(url:)`.
    func cleanup()
}
