import Foundation
import Observation
import os.log
import AppKit

// MARK: - AttachmentAddViewModel

/// ViewModel for the single-file attachment add flow (tasks 6.1–6.4b).
///
/// Lifecycle:
/// 1. Created with `cipherId` when the user taps "Add Attachment" for a specific vault item.
/// 2. `selectFile()` opens `NSOpenPanel` and reads file metadata (size only) for validation.
/// 3. On confirmation, `confirm()` reads the file bytes, uploads, and zeroes the buffer.
/// 4. `cancel()` zeroes any buffered bytes and signals dismissal.
///
/// - Security goal: raw file bytes are held in memory only between `confirm()` call and
///   upload completion (success or failure). Both paths zero the buffer immediately after
///   the upload call returns (Constitution §III).
///
/// - File bytes are NOT read at selection time — they are read at the moment the user
///   presses Confirm, minimising how long sensitive data is resident in memory.
///
/// - Testability: The `filePicker` closure is injectable so unit tests can bypass
///   `NSOpenPanel` (which requires an interactive session and cannot run in XCTest).
@Observable
@MainActor
final class AttachmentAddViewModel {

    // MARK: - Injected

    private let cipherId: String
    private let uploadUseCase: any UploadAttachmentUseCase
    /// Injectable file-picker closure — defaults to `NSOpenPanel` in production.
    /// Receives no arguments and returns `(url: URL, bytes: Int)` on success or `nil` on cancel.
    private let filePicker: () -> (url: URL, bytes: Int)?

    private let logger = Logger(subsystem: "com.prizm", category: "attachments")

    // MARK: - State (observable)

    /// URL of the file selected via `NSOpenPanel`. Non-nil once the user picks a file.
    private(set) var selectedFileURL: URL?

    /// Display name for the selected file (derived from `selectedFileURL`).
    private(set) var fileName: String = ""

    /// Byte count of the selected file (read at selection time for size validation only —
    /// bytes are NOT loaded into memory until Confirm).
    private(set) var fileSizeBytes: Int = 0

    /// `true` while `NSOpenPanel.runModal()` is blocking the main thread.
    /// Used by `AttachmentsSectionView` to disable the "Add Attachment" button and
    /// show a spinner so the UI does not appear unresponsive during the modal call.
    private(set) var isPickingFile: Bool = false

    /// `true` while the Confirm sheet is presented.
    private(set) var isConfirming: Bool = false

    /// `true` while an upload is in-flight.
    private(set) var isUploading: Bool = false

    /// Non-nil when the file exceeds 500 MB (shown inline before confirmation).
    private(set) var sizeError: String? = nil

    /// Non-nil when the upload fails (shown in the confirmation sheet).
    private(set) var uploadError: String? = nil

    /// `true` when the sheet should be dismissed (set by `cancel()` or upload success).
    private(set) var isDismissed: Bool = false

    /// Advisory message shown when file is ≥50 MB but ≤500 MB.
    private(set) var sizeAdvisory: String? = nil

    // MARK: - Private

    /// Holds the in-flight upload task so `cancel()` can cancel it.
    private var uploadTask: Task<Void, Never>? = nil

    // MARK: - Init

    init(
        cipherId: String,
        uploadUseCase: any UploadAttachmentUseCase,
        filePicker: (() -> (url: URL, bytes: Int)?)? = nil
    ) {
        self.cipherId      = cipherId
        self.uploadUseCase = uploadUseCase
        self.filePicker    = filePicker ?? AttachmentAddViewModel.defaultNSOpenPanel
    }

    /// Default file picker implementation using `NSOpenPanel.runModal()`.
    /// Extracted as a static so it is not captured in `self` and does not keep the ViewModel alive.
    private static let defaultNSOpenPanel: () -> (url: URL, bytes: Int)? = {
        let panel = NSOpenPanel()
        panel.canChooseFiles          = true
        panel.canChooseDirectories    = false
        panel.allowsMultipleSelection = false
        panel.message                 = "Choose a file to attach"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return (url, bytes)
    }

    // MARK: - File selection (task 6.2)

    /// Invokes `filePicker` (defaults to `NSOpenPanel`) and validates the chosen file.
    ///
    /// Reading file size at selection time (rather than at confirm time) lets the UI display
    /// the size and advisory/error message immediately. Bytes are NOT read here.
    func selectFile() {
        isPickingFile = true
        defer { isPickingFile = false }
        guard let (url, bytes) = filePicker() else { return }

        // Max 500 MB (task 6.2)
        let maxBytes = 500 * 1024 * 1024
        if bytes > maxBytes {
            sizeError = "File exceeds the 500 MB limit (\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))."
            return
        }

        let advisoryThreshold = 50 * 1024 * 1024
        sizeAdvisory = bytes >= advisoryThreshold
            ? "Large files take longer to encrypt and upload."
            : nil

        selectedFileURL = url
        fileName        = url.lastPathComponent
        fileSizeBytes   = bytes
        sizeError       = nil
        isConfirming    = true
    }

    // MARK: - Confirm (task 6.4)

    /// Reads file bytes, uploads, then zeroes the buffer.
    ///
    /// The upload `Task` is stored in `uploadTask` so `cancel()` can cancel it in-flight.
    /// - Security: file bytes are zeroed immediately after the upload call returns,
    ///   whether it succeeds or fails (Constitution §III).
    func confirm() {
        guard let url = selectedFileURL, !isUploading else { return }
        uploadError = nil
        isUploading = true

        uploadTask = Task { [weak self] in
            guard let self else { return }

            // Read bytes at confirm time, not at selection time (§III).
            var fileData: Data
            do {
                fileData = try Data(contentsOf: url)
            } catch {
                self.uploadError = "Could not read file: \(error.localizedDescription)"
                self.isUploading = false
                self.uploadTask  = nil
                return
            }

            do {
                _ = try await self.uploadUseCase.execute(
                    cipherId: self.cipherId,
                    fileName: self.fileName,
                    data:     fileData
                )
                // Zero file bytes on success immediately (§III).
                fileData.resetBytes(in: 0..<fileData.count)
                self.isDismissed = true
            } catch AttachmentError.premiumRequired {
                fileData.resetBytes(in: 0..<fileData.count)
                self.uploadError = "Attachment storage requires a premium Bitwarden subscription."
            } catch is CancellationError {
                // Task was cancelled via cancel() — buffer already zeroed there.
                fileData.resetBytes(in: 0..<fileData.count)
            } catch {
                fileData.resetBytes(in: 0..<fileData.count)
                self.uploadError = "Upload failed: \(error.localizedDescription)"
                logger.error("upload failed: \(error.localizedDescription, privacy: .public)")
            }

            self.isUploading = false
            self.uploadTask  = nil
        }
    }

    // MARK: - Cancel (task 6.4b)

    /// Cancels any in-flight upload, zeroes the file data buffer, and signals dismissal.
    ///
    /// - Security: file bytes held by the upload Task are zeroed when the Task catches
    ///   `CancellationError` in `confirm()`. No discard prompt is shown.
    func cancel() {
        uploadTask?.cancel()
        uploadTask   = nil
        isUploading  = false
        isDismissed  = true
    }
}
