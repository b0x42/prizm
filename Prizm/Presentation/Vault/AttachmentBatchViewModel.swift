import Foundation
import Observation
import os.log

// MARK: - BatchItemState

/// Per-item upload state for the batch attachment flow.
nonisolated enum BatchItemState: Equatable {
    case valid                  // passes size validation; not yet uploaded
    case tooLarge               // exceeds 500 MB limit
    case uploading              // upload Task is in-flight
    case succeeded              // upload completed successfully
    case failed(String)         // upload failed with a human-readable message

    static func == (lhs: BatchItemState, rhs: BatchItemState) -> Bool {
        switch (lhs, rhs) {
        case (.valid, .valid), (.tooLarge, .tooLarge),
             (.uploading, .uploading), (.succeeded, .succeeded): return true
        case (.failed(let l), .failed(let r)):                   return l == r
        default: return false
        }
    }
}

// MARK: - AttachmentBatchItem

/// Model for a single file in the batch upload sheet.
///
/// - `fileURL` is the local Finder URL from the drop — distinct from `Attachment.url`
///   which is a server download URL.
/// - File bytes are NOT read here; they are read at confirm time per §III.
nonisolated struct AttachmentBatchItem: Identifiable {
    let id:        UUID
    let fileURL:   URL
    let fileName:  String
    let sizeName:  String
    let sizeBytes: Int
    var state:     BatchItemState

    init(fileURL: URL, sizeBytes: Int) {
        self.id        = UUID()
        self.fileURL   = fileURL
        self.fileName  = fileURL.lastPathComponent
        self.sizeBytes = sizeBytes
        self.sizeName  = ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
        self.state     = sizeBytes > 500 * 1024 * 1024 ? .tooLarge : .valid
    }
}

// MARK: - AttachmentBatchViewModel

/// ViewModel for the drag-and-drop batch attachment upload flow (tasks 6b.2–6b.8).
///
/// Lifecycle:
/// 1. Created with `cipherId` when files are dropped onto the Attachments section.
/// 2. `loadItems(from urls:)` reads file sizes (not bytes) to populate the item list.
/// 3. `confirm()` launches concurrent upload Tasks — one per valid item.
/// 4. `cancel()` cancels all in-flight tasks and zeroes buffered bytes.
///
/// - Security goal: file bytes are held in memory only during each individual upload.
///   Each Task reads its file, uploads it, then zeroes the buffer immediately — regardless
///   of success or failure (Constitution §III). Files already partially uploaded appear as
///   "Upload incomplete" on the next sync.
@Observable
@MainActor
final class AttachmentBatchViewModel: Identifiable {

    let id = UUID()

    // MARK: - Injected

    private let cipherId: String
    private let uploadUseCase: any UploadAttachmentUseCase

    private let logger = Logger(subsystem: "com.prizm", category: "attachments")

    // MARK: - State (observable)

    /// All items in the batch (valid and too-large).
    private(set) var items: [AttachmentBatchItem] = []

    /// `true` while at least one upload Task is in-flight.
    private(set) var isUploading: Bool = false

    /// `true` when the sheet should be dismissed.
    private(set) var isDismissed: Bool = false

    // MARK: - Derived state

    /// `true` if at least one item is valid for upload.
    var canConfirm: Bool {
        !isUploading && items.contains { $0.state == .valid }
    }

    // MARK: - Private

    /// One Task per valid item — held so `cancel()` can cancel them.
    private var uploadTasks: [Task<Void, Never>] = []

    // MARK: - Init

    init(cipherId: String, uploadUseCase: any UploadAttachmentUseCase) {
        self.cipherId      = cipherId
        self.uploadUseCase = uploadUseCase
    }

    // MARK: - Load items from dropped URLs (task 6b.2)

    /// Reads file size (not bytes) for each URL and populates `items`.
    ///
    /// Called by the drop handler immediately after drop to populate the batch sheet
    /// before the user clicks Confirm.
    func loadItems(from urls: [URL]) {
        items = urls.map { url in
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return AttachmentBatchItem(fileURL: url, sizeBytes: bytes)
        }
    }

    // MARK: - Confirm (task 6b.5)

    /// Launches concurrent upload Tasks for all valid items.
    ///
    /// Each Task: (1) reads file bytes at confirm time; (2) uploads; (3) zeroes bytes.
    /// Per-item state is updated as each Task completes. The sheet dismisses automatically
    /// when all items have succeeded.
    func confirm() {
        guard !isUploading else { return }
        isUploading = true

        let validIndices = items.indices.filter { items[$0].state == .valid }
        guard !validIndices.isEmpty else {
            isUploading = false
            return
        }

        for index in validIndices {
            items[index].state = .uploading
            let item = items[index]

            let task = Task { [weak self] in
                guard let self else { return }
                await self.uploadItem(item, at: index)
            }
            uploadTasks.append(task)
        }

        // Watch for all-done to auto-dismiss
        Task { [weak self] in
            guard let self else { return }
            for t in self.uploadTasks { await t.value }
            self.uploadTasks.removeAll()
            self.isUploading = false
            // Auto-dismiss only if all items succeeded
            if self.items.allSatisfy({ $0.state == .succeeded || $0.state == .tooLarge }) {
                self.isDismissed = true
            }
        }
    }

    // MARK: - Cancel (task 6b.7)

    /// Cancels all in-flight upload Tasks and signals dismissal.
    ///
    /// Files already partially uploaded will show as "Upload incomplete" on the next sync.
    /// - Security: each Task catches `CancellationError` and zeroes its file bytes before exiting.
    func cancel() {
        for task in uploadTasks { task.cancel() }
        uploadTasks.removeAll()
        isUploading  = false
        isDismissed  = true
    }

    // MARK: - Vault lock (task 6b.6)

    /// Cancels all tasks when the vault is locked during a batch upload.
    ///
    /// Identical to `cancel()` — both zero all in-flight buffers and dismiss.
    func handleVaultLock() {
        cancel()
    }

    // MARK: - Private

    private func uploadItem(_ item: AttachmentBatchItem, at index: Int) async {
        var fileData: Data
        do {
            fileData = try Data(contentsOf: item.fileURL)
        } catch {
            items[index].state = .failed("Could not read file: \(error.localizedDescription)")
            return
        }

        do {
            _ = try await uploadUseCase.execute(
                cipherId: cipherId,
                fileName: item.fileName,
                data:     fileData
            )
            fileData.resetBytes(in: 0..<fileData.count)
            items[index].state = .succeeded
            logger.info("batch upload succeeded: \(item.fileName, privacy: .public)")
        } catch is CancellationError {
            fileData.resetBytes(in: 0..<fileData.count)
            // State stays .uploading — will be cleaned up by cancel()
        } catch {
            fileData.resetBytes(in: 0..<fileData.count)
            let msg = error.localizedDescription
            items[index].state = .failed(msg)
            logger.error("batch upload failed: \(item.fileName, privacy: .public) — \(msg, privacy: .public)")
        }
    }
}
