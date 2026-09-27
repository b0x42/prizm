import QuickLook
import SwiftUI
import UniformTypeIdentifiers

// MARK: - AttachmentsSectionView

/// Attachments section card in the vault item detail pane.
///
/// In read mode it exposes only Preview and Download. Mutation controls and file drops
/// are enabled explicitly for edit flows.
///
/// Action closures are wired by the parent view. Defaults remain no-ops for lightweight
/// previews and callers that do not provide attachment infrastructure.
struct AttachmentsSectionView: View {

    let attachments: [Attachment]
    var isEditing = false

    // Section-level callbacks
    var onAddTapped:  () -> Void       = {}
    var onDropFiles:  ([URL]) -> Void  = { _ in }

    /// `true` while `NSOpenPanel` is blocking - disables the "Add Attachment" button
    /// and shows a small spinner so the UI doesn't appear frozen.
    var isPicking: Bool = false

    /// Factory for `AttachmentRowViewModel` - injected from AppContainer so the
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

                if isEditing {
                    Divider()
                    addButton
                }
            }
        }
        .overlay {
            if isEditing {
                dragBorder
            }
        }
        .onDrop(of: isEditing ? [.fileURL] : [], isTargeted: $isDragTargeted) { providers in
            guard isEditing else { return false }
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
                AttachmentRowViewWithViewModel(
                    attachment: attachment,
                    isEditing: isEditing,
                    factory: factory
                )
            } else {
                AttachmentRowView(attachment: attachment, isEditing: isEditing)
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
        .accessibilityLabel("Add Attachment")
        .accessibilityIdentifier(AccessibilityID.Attachment.addButton)
    }

    @ViewBuilder
    private var dragBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.accentColor, lineWidth: 2)
            .opacity(isDragTargeted ? 1 : 0)
            .animation(AccessibilityInfo.prefersReducedMotion ? nil : .easeInOut(duration: 0.15), value: isDragTargeted)
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
    let isEditing: Bool

    @State private var viewModel: AttachmentRowViewModel
    @State private var showDeleteAlert = false
    @Environment(\.colorSchemeContrast) private var contrast

    init(
        attachment: Attachment,
        isEditing: Bool,
        factory: (Attachment) -> AttachmentRowViewModel
    ) {
        self.attachment = attachment
        self.isEditing = isEditing
        // State(initialValue:) stores the value only on the first insertion into the
        // view hierarchy; subsequent re-renders preserve the existing state value, so
        // the factory is not called more than once per logical row lifetime.
        _viewModel      = State(initialValue: factory(attachment))
    }

    var body: some View {
        VStack(spacing: 0) {
            AttachmentRowView(
                attachment:   viewModel.attachment,
                isEditing:    isEditing,
                onPreview:    { viewModel.preview() },
                onSaveToDisk: { viewModel.saveToDisk() },
                onDelete:     { showDeleteAlert = true },
                onRetry:      { viewModel.retryUpload() }
            )

            if let error = viewModel.actionError ?? viewModel.retryError {
                HStack(alignment: .top, spacing: Spacing.headerGap) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
                        Text(viewModel.actionErrorTitle ?? "Attachment unavailable")
                            .font(Typography.fieldValue.weight(.semibold))
                        Text(error)
                            .font(Typography.listSubtitle)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.rowHorizontal)
                .padding(.vertical, Spacing.bannerVertical)
                .background(
                    Color.red.opacity(Opacity.errorBanner(contrast)),
                    in: RoundedRectangle(cornerRadius: Spacing.itemIconCornerRadius)
                )
                .padding(.horizontal, Spacing.rowHorizontal)
                .padding(.top, Spacing.rowVertical)
                .padding(.bottom, Spacing.rowVertical)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
            }
        }
        .quickLookPreview($viewModel.previewURL)
        .alert("Delete Attachment", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { viewModel.delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(verbatim: "\u{201C}" + viewModel.attachment.fileName + "\u{201D} will be permanently deleted.")
        }
        .onChange(of: viewModel.actionError) { _, error in
            if let error {
                AccessibilityNotification.Announcement(error).post()
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
