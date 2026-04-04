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
            Label("Add Attachment", systemImage: "paperclip")
                .font(Typography.fieldValue)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
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
private struct AttachmentRowViewWithViewModel: View {

    let attachment: Attachment
    let factory:    (Attachment) -> AttachmentRowViewModel

    @State private var viewModel: AttachmentRowViewModel?
    @State private var showDeleteAlert = false

    var body: some View {
        Group {
            if let vm = viewModel {
                AttachmentRowView(
                    attachment:   vm.attachment,
                    onOpen:       { vm.open() },
                    onSaveToDisk: { vm.saveToDisk() },
                    onDelete:     { showDeleteAlert = true },
                    onRetry:      { vm.retryUpload() }
                )
                .alert("Delete Attachment", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) { vm.delete() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(verbatim: "\u{201C}\(vm.attachment.fileName)\u{201D} will be permanently deleted.")
                }
                .overlay(alignment: .bottom) {
                    if let error = vm.actionError ?? vm.retryError {
                        Text(error)
                            .font(Typography.utility)
                            .foregroundStyle(.red)
                            .padding(.horizontal, Spacing.rowHorizontal)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onAppear { viewModel = factory(attachment) }
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
