import SwiftUI
import UniformTypeIdentifiers

// MARK: - AttachmentsSectionView

/// Attachments section card in the vault item detail pane.
///
/// Always visible regardless of attachment count — shows an empty state message and
/// the "Add Attachment" button even when the item has no attachments (task 5.1).
///
/// Supports:
/// - Single-file add via `NSOpenPanel` triggered by the "Add Attachment" button (task 5.3).
/// - Drag-and-drop of one or more files onto the card, highlighted with a border while
///   a file is dragged over (task 5.4).
///
/// Action closures (`onAddTapped`, `onDropFiles`, per-row `onOpen`/`onSaveToDisk`/`onDelete`/
/// `onRetry`) are wired by the parent view. The defaults are no-ops so task-5 callers compile
/// before the ViewModels from tasks 6 and 7 are wired up.
struct AttachmentsSectionView: View {

    let attachments: [Attachment]

    // Section-level callbacks
    var onAddTapped:  () -> Void       = {}
    var onDropFiles:  ([URL]) -> Void  = { _ in }

    /// `true` while `NSOpenPanel` is blocking — disables the "Add Attachment" button
    /// and shows a small spinner so the UI doesn't appear frozen.
    var isPicking: Bool = false

    /// Factory for `AttachmentRowViewModel` — injected from AppContainer so the
    /// section view never imports Data layer types directly (Constitution §II).
    /// When nil (e.g. in task-5 callers before ViewModels are wired), row actions no-op.
    var makeRowViewModel: ((Attachment) -> AttachmentRowViewModel)? = nil

    @State private var isDragTargeted = false

    var body: some View {
        DetailSectionCard("Attachments") {
            VStack(alignment: .leading, spacing: 0) {
                if attachments.isEmpty {
                    emptyState
                } else {
                    attachmentRows
                }

                Divider()
                addButton
            }
        }
        .overlay(dragBorder)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            extractURLs(from: providers)
            return true
        }
        .accessibilityIdentifier(AccessibilityID.Attachment.sectionCard)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyState: some View {
        HStack {
            Text("No attachments")
                .font(Typography.fieldLabel)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }

    @ViewBuilder
    private var attachmentRows: some View {
        ForEach(attachments) { attachment in
            if attachment.id != attachments.first?.id { Divider() }
            if let factory = makeRowViewModel {
                AttachmentRowViewWithViewModel(attachment: attachment, factory: factory)
            } else {
                AttachmentRowView(attachment: attachment)
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        Button {
            onAddTapped()
        } label: {
            HStack(spacing: 6) {
                if isPicking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperclip")
                }
                Text("Add Attachment")
                    .font(Typography.fieldValue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPicking ? Color.secondary : Color.accentColor)
        .disabled(isPicking)
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
        .accessibilityIdentifier(AccessibilityID.Attachment.addButton)
    }

    @ViewBuilder
    private var dragBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.accentColor, lineWidth: 2)
            .opacity(isDragTargeted ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
    }

    // MARK: - Row with ViewModel (wired)

}

/// Thin wrapper that creates an `AttachmentRowViewModel` for a single row and forwards
/// its actions to `AttachmentRowView`. Separated so the ForEach in `AttachmentsSectionView`
/// can own one ViewModel per row without nesting @State awkwardly.
///
/// The ViewModel is initialised eagerly via `State(initialValue:)` so the row renders
/// on the very first pass. The previous `onAppear`-based pattern left an empty `Group`
/// visible until `onAppear` fired, which could be delayed or skipped on macOS when the
/// wrapping `Group` has no visual content on first render.
private struct AttachmentRowViewWithViewModel: View {

    let attachment: Attachment
    let factory:    (Attachment) -> AttachmentRowViewModel

    @State private var viewModel: AttachmentRowViewModel
    @State private var showDeleteAlert = false

    init(attachment: Attachment, factory: (Attachment) -> AttachmentRowViewModel) {
        self.attachment = attachment
        self.factory    = factory
        // State(initialValue:) stores the value only on the first insertion into the
        // view hierarchy; subsequent re-renders preserve the existing state value, so
        // the factory is not called more than once per logical row lifetime.
        _viewModel      = State(initialValue: factory(attachment))
    }

    var body: some View {
        AttachmentRowView(
            attachment:   viewModel.attachment,
            onOpen:       { viewModel.open() },
            onSaveToDisk: { viewModel.saveToDisk() },
            onDelete:     { showDeleteAlert = true },
            onRetry:      { viewModel.retryUpload() }
        )
        .alert("Delete Attachment", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { viewModel.delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(verbatim: "\u{201C}" + viewModel.attachment.fileName + "\u{201D} will be permanently deleted.")
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.actionError ?? viewModel.retryError {
                Text(error)
                    .font(Typography.utility)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Spacing.rowHorizontal)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Drop handling
private extension AttachmentsSectionView {

    /// Asynchronously extracts file URLs from the dropped item providers and forwards
    /// them to `onDropFiles` on the main actor.
    ///
    /// `NSItemProvider.loadItem` is a completion-based API, so we use `Task` + a local
    /// accumulator to collect all URLs before calling back. The drop perform closure
    /// must return `Bool` synchronously, so we accept the drop immediately and do the
    /// async extraction here.
    func extractURLs(from providers: [NSItemProvider]) {
        Task {
            var urls: [URL] = []
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let url = await loadFileURL(from: provider) {
                    urls.append(url)
                }
            }
            if !urls.isEmpty {
                onDropFiles(urls)
            }
        }
    }

    /// Wraps `NSItemProvider.loadItem` in an async/await continuation.
    func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
