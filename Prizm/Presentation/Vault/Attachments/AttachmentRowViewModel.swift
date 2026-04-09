import Foundation
import Observation
import os.log

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
///
/// - AppKit dependencies (`NSWorkspace`, `NSSavePanel`, `NSOpenPanel`) are injected as
///   closures from the App layer (`AppContainer`) to keep the Presentation layer free of
///   AppKit imports (Constitution §II).
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
    /// Injectable file-saver closure. Provided by AppContainer (defaults to NSSavePanel).
    private let fileSaver:            @MainActor (_ suggestedName: String) -> URL?
    /// Injectable file-picker for Retry. Provided by AppContainer (defaults to NSOpenPanel).
    private let retryFilePicker:      @MainActor () -> URL?
    /// Injectable file-opener closure. Provided by AppContainer (defaults to NSWorkspace.shared.open).
    private let fileOpener:           @MainActor (_ url: URL) -> Void

    private let logger = Logger(subsystem: "com.prizm", category: "attachments")

    /// Called after a successful delete or retry-upload so the parent view can refresh
    /// `itemSelection` and reflect the updated attachment list without waiting for a sync.
    var onAttachmentChanged: (() -> Void)? = nil

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
        fileSaver:       @escaping @MainActor (_ suggestedName: String) -> URL?,
        retryFilePicker: @escaping @MainActor () -> URL?,
        fileOpener:      @escaping @MainActor (_ url: URL) -> Void
    ) {
        self.cipherId        = cipherId
        self.attachment      = attachment
        self.downloadUseCase = downloadUseCase
        self.deleteUseCase   = deleteUseCase
        self.uploadUseCase   = uploadUseCase
        self.tempFileManager = tempFileManager
        self.fileSaver       = fileSaver
        self.retryFilePicker = retryFilePicker
        self.fileOpener      = fileOpener
    }

    // MARK: - Open (task 7.2b)

    func open() {
        guard !isLoading else { return }
        isLoading   = true
        actionError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                var data = try await self.downloadUseCase.execute(
                    cipherId:   self.cipherId,
                    attachment: self.attachment
                )
                let tmpURL = try self.writeTempFile(data: data)
                data.resetBytes(in: 0..<data.count)
                self.fileOpener(tmpURL)
                self.tempFileManager.register(url: tmpURL)

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

    func saveToDisk() {
        guard !isLoading else { return }
        isLoading   = true
        actionError = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let saveURL = self.fileSaver(self.attachment.fileName) else {
                self.isLoading = false
                return
            }
            do {
                var data = try await self.downloadUseCase.execute(
                    cipherId:   self.cipherId,
                    attachment: self.attachment
                )
                try data.write(to: saveURL)
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
                self.onAttachmentChanged?()
            } catch {
                self.actionError = "Could not delete attachment: \(error.localizedDescription)"
                self.logger.error("delete failed: \(error.localizedDescription, privacy: .public)")
            }
            self.isLoading = false
        }
    }

    // MARK: - Retry Upload (task 6d.2)

    func retryUpload() {
        guard !isRetrying, attachment.isUploadIncomplete else { return }
        isRetrying  = true
        retryError  = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let fileURL = self.retryFilePicker() else {
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
                try await self.deleteUseCase.execute(
                    cipherId:     self.cipherId,
                    attachmentId: self.attachment.id
                )
                _ = try await self.uploadUseCase.execute(
                    cipherId: self.cipherId,
                    fileName: self.attachment.fileName,
                    data:     fileData
                )
                fileData.resetBytes(in: 0..<fileData.count)
                self.onAttachmentChanged?()
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
}
