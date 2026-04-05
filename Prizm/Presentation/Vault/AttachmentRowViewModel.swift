import Foundation
import Observation
import os.log
import AppKit

// MARK: - AttachmentRowViewModel

/// ViewModel for a single attachment row in the vault item detail pane (task 7.1).
///
/// Manages Open, Save to Disk, Delete, and Retry Upload actions for one attachment.
///
/// - Security goal: plaintext file bytes are written to a temp file for Open, and to a
///   user-chosen path for Save. The temp file is zeroed and deleted after 30 seconds
///   (or on next foreground) by `TempFileManaging`. For Save, the plaintext is written
///   directly and the in-memory buffer is zeroed immediately after (Constitution §III).
///
/// - `attachment.isUploadIncomplete` drives the UI: when true, the row shows "Upload
///   incomplete" + Retry; otherwise it shows Open / Save / Delete.
@Observable
@MainActor
final class AttachmentRowViewModel {

    // MARK: - Injected

    private let cipherId:             String
    let attachment:                   Attachment       // accessed by view
    private let downloadUseCase:      any DownloadAttachmentUseCase
    private let deleteUseCase:        any DeleteAttachmentUseCase
    private let uploadUseCase:        any UploadAttachmentUseCase
    private let tempFileManager:      any TempFileManaging
    /// Injectable file-saver: defaults to `NSSavePanel`. Injected in tests.
    /// Must be `@MainActor` — AppKit panel classes require main-actor isolation
    /// on macOS 26 and will trap at the constructor site otherwise.
    private let fileSaver:            @MainActor (_ suggestedName: String) -> URL?
    /// Injectable file-picker for Retry: defaults to `NSOpenPanel`. Injected in tests.
    private let retryFilePicker:      @MainActor () -> URL?

    private let logger = Logger(subsystem: "com.prizm", category: "attachments")

    // MARK: - State (observable)

    private(set) var isLoading:   Bool    = false
    private(set) var actionError: String? = nil
    private(set) var isRetrying:  Bool    = false
    private(set) var retryError:  String? = nil

    // MARK: - Init

    init(
        cipherId:        String,
        attachment:      Attachment,
        downloadUseCase: any DownloadAttachmentUseCase,
        deleteUseCase:   any DeleteAttachmentUseCase,
        uploadUseCase:   any UploadAttachmentUseCase,
        tempFileManager: any TempFileManaging,
        fileSaver:       (@MainActor (_ suggestedName: String) -> URL?)? = nil,
        retryFilePicker: (@MainActor () -> URL?)? = nil
    ) {
        self.cipherId        = cipherId
        self.attachment      = attachment
        self.downloadUseCase = downloadUseCase
        self.deleteUseCase   = deleteUseCase
        self.uploadUseCase   = uploadUseCase
        self.tempFileManager = tempFileManager
        self.fileSaver       = fileSaver ?? AttachmentRowViewModel.defaultSavePanel(suggestedName:)
        self.retryFilePicker = retryFilePicker ?? AttachmentRowViewModel.defaultOpenPanel
    }

    // MARK: - Open (task 7.2b)

    /// Downloads and opens the attachment in the default application.
    ///
    /// Writes plaintext to `<tmpdir>/<uuid>.<ext>`, opens it with NSWorkspace, then
    /// registers the file with `TempFileManaging` for cleanup after 30 seconds.
    func open() {
        guard !isLoading else { return }
        isLoading   = true
        actionError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await self.downloadUseCase.execute(
                    cipherId:   self.cipherId,
                    attachment: self.attachment
                )
                let tmpURL = try self.writeTempFile(data: data)
                NSWorkspace.shared.open(tmpURL)
                self.tempFileManager.register(url: tmpURL)

                // Schedule cleanup from the foreground — covers apps that stay in foreground.
                Task {
                    try? await Task.sleep(for: .seconds(30))
                    self.tempFileManager.cleanup()
                }

                self.logger.info("open: opened \(self.attachment.id, privacy: .public)")
            } catch {
                self.actionError = "Could not open file: \(error.localizedDescription)"
                self.logger.error("open failed: \(error.localizedDescription, privacy: .public)")
            }
            self.isLoading = false
        }
    }

    // MARK: - Save to Disk (task 7.3)

    /// Downloads and writes the attachment to the user-chosen path via `NSSavePanel`.
    ///
    /// Zeroes the in-memory buffer immediately after writing (Constitution §III).
    func saveToDisk() {
        guard !isLoading else { return }
        isLoading   = true
        actionError = nil

        // NSSavePanel must be constructed outside the SwiftUI button-action dispatch frame on
        // macOS 26 — calling it synchronously from a SwiftUI action handler triggers an AppKit
        // main-actor assertion (EXC_BREAKPOINT) even on the main thread. Deferring via Task
        // advances past the current run-loop turn, satisfying the requirement.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let saveURL = self.fileSaver(self.attachment.fileName) else {
                // User cancelled the panel.
                self.isLoading = false
                return
            }
            do {
                var data = try await self.downloadUseCase.execute(
                    cipherId:   self.cipherId,
                    attachment: self.attachment
                )
                try data.write(to: saveURL)
                // Zero plaintext buffer immediately after writing (§III).
                data.resetBytes(in: 0..<data.count)
                self.logger.info("saveToDisk: saved \(self.attachment.id, privacy: .public)")
            } catch {
                self.actionError = "Could not save file: \(error.localizedDescription)"
                self.logger.error("saveToDisk failed: \(error.localizedDescription, privacy: .public)")
            }
            self.isLoading = false
        }
    }

    // MARK: - Delete (task 7.4)

    /// Deletes the attachment. Confirmation alert is shown by the View before calling this.
    func delete() {
        guard !isLoading else { return }
        isLoading   = true
        actionError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.deleteUseCase.execute(
                    cipherId:     self.cipherId,
                    attachmentId: self.attachment.id
                )
                self.logger.info("delete: removed \(self.attachment.id, privacy: .public)")
                // The row disappears via VaultRepository.updateAttachments — no extra state needed.
            } catch {
                self.actionError = "Could not delete attachment: \(error.localizedDescription)"
                self.logger.error("delete failed: \(error.localizedDescription, privacy: .public)")
            }
            self.isLoading = false
        }
    }

    // MARK: - Retry Upload (task 6d.2)

    /// Retries an incomplete upload: opens a file picker, deletes the orphaned metadata,
    /// then uploads the freshly selected file as a new attachment.
    ///
    /// - Security: file bytes are read at picker confirmation, uploaded, then zeroed.
    func retryUpload() {
        guard !isRetrying, attachment.isUploadIncomplete else { return }
        isRetrying  = true
        retryError  = nil

        // Same run-loop-turn deferral as saveToDisk — NSOpenPanel asserts @MainActor at
        // the constructor site on macOS 26 when called synchronously from a SwiftUI action.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let fileURL = self.retryFilePicker() else {
                // User cancelled the panel.
                self.isRetrying = false
                return
            }

            var fileData: Data
            do {
                fileData = try Data(contentsOf: fileURL)
            } catch {
                self.retryError = "Could not read file: \(error.localizedDescription)"
                self.isRetrying = false
                return
            }

            do {
                // Step 1: Delete the orphaned server metadata record.
                try await self.deleteUseCase.execute(
                    cipherId:     self.cipherId,
                    attachmentId: self.attachment.id
                )

                // Step 2: Fresh upload.
                _ = try await self.uploadUseCase.execute(
                    cipherId: self.cipherId,
                    fileName: self.attachment.fileName,
                    data:     fileData
                )

                // Zero bytes on success (§III).
                fileData.resetBytes(in: 0..<fileData.count)
                // The incomplete row disappears and a new normal row appears via updateAttachments.
                self.logger.info("retryUpload: succeeded for \(self.attachment.id, privacy: .public)")
            } catch {
                fileData.resetBytes(in: 0..<fileData.count)
                self.retryError = "Retry failed: \(error.localizedDescription)"
                self.logger.error("retryUpload failed: \(error.localizedDescription, privacy: .public)")
            }

            self.isRetrying = false
        }
    }

    // MARK: - Private helpers

    private func writeTempFile(data: Data) throws -> URL {
        let ext  = URL(fileURLWithPath: attachment.fileName).pathExtension
        let name = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    // MARK: - Default panel implementations (production)

    /// `@MainActor` is required: on macOS 26, AppKit panel classes assert main-actor
    /// isolation at the constructor site (EXC_BREAKPOINT) when accessed via a
    /// non-isolated function pointer, even when the calling thread is the main thread.
    @MainActor
    private static func defaultSavePanel(suggestedName: String) -> URL? {
        let panel                 = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.message             = "Choose where to save the attachment"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Same `@MainActor` requirement as `defaultSavePanel`.
    @MainActor
    private static func defaultOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles          = true
        panel.canChooseDirectories    = false
        panel.allowsMultipleSelection = false
        panel.message                 = "Select the file to re-upload"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
