import SwiftUI

// MARK: - ItemEditView

/// Modal sheet container for editing a vault item.
///
/// Owns the Save and Discard toolbar buttons, the per-type edit form, and the inline
/// error banner shown on save failure. Sheet presentation is managed by the caller
/// (`ItemDetailView`) which toggles `isPresented` based on `viewModel.isDismissed`.
///
/// Keyboard shortcuts:
/// - ⌘S: Save (wired via `.keyboardShortcut` on the Save button)
/// - ⌘E: No-op (sheet is already open; handled in ItemDetailView)
/// - Esc: Triggers the same discard logic as the Discard button (via `.onExitCommand`)
struct ItemEditView: View {

    @ObservedObject var viewModel: ItemEditViewModel

    /// Drives sheet dismissal from the parent.
    @Binding var isPresented: Bool

    /// Whether the discard confirmation alert is currently showing.
    @State private var showingDiscardAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Error banner — shown when a save fails; dismisses on retry.
            if let error = viewModel.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(Typography.fieldValue)
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .accessibilityIdentifier(AccessibilityID.Edit.errorBanner)
            }

            // Name field — always the first editable field regardless of item type (spec §3.1).
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $viewModel.draft.name)
                    .font(Typography.pageTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.top, Spacing.pageTop)
                    .padding(.bottom, 4)

                // Live validation: shown immediately when Name field becomes empty (spec §3.2).
                if let nameError = viewModel.nameValidationError {
                    Text(nameError)
                        .font(Typography.utility)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Spacing.pageMargin)
                }
            }
            .padding(.bottom, Spacing.pageHeaderBottom)

            Divider()

            // Per-type edit form.
            typeEditForm
                .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 480, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Discard") {
                    handleDiscard()
                }
                .disabled(viewModel.isSaving)
                .help("Discard changes (Esc)")
                .accessibilityIdentifier(AccessibilityID.Edit.discardButton)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.isSaving ? "Saving…" : "Save") {
                    viewModel.save()
                }
                .disabled(!viewModel.canSave)
                // ⌘S triggers save while this sheet is open and the form is valid (spec §6.1).
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityIdentifier(AccessibilityID.Edit.saveButton)
            }
        }
        // Esc key invokes the same discard logic as the Discard button (spec §8.3).
        .onExitCommand {
            handleDiscard()
        }
        // Discard confirmation alert (spec §8.3).
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) {
                viewModel.discard()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Your unsaved changes will be lost.")
        }
        // Dismiss the sheet when the ViewModel signals it (save success or discard).
        .onChange(of: viewModel.isDismissed) { _, dismissed in
            if dismissed { isPresented = false }
        }
    }

    // MARK: - Per-type dispatch

    @ViewBuilder
    private var typeEditForm: some View {
        switch viewModel.draft.content {
        case .login(let content):
            // Use a local binding projected from the draft's associated value.
            LoginEditForm(draft: Binding(
                get:  {
                    guard case .login(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .login(newContent) }
            ))

        case .card(let content):
            CardEditForm(draft: Binding(
                get:  {
                    guard case .card(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .card(newContent) }
            ))

        case .identity(let content):
            IdentityEditForm(draft: Binding(
                get:  {
                    guard case .identity(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .identity(newContent) }
            ))

        case .secureNote(let content):
            SecureNoteEditForm(draft: Binding(
                get:  {
                    guard case .secureNote(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .secureNote(newContent) }
            ))

        case .sshKey(let content):
            SSHKeyEditForm(draft: Binding(
                get:  {
                    guard case .sshKey(let c) = viewModel.draft.content else { return content }
                    return c
                },
                set:  { newContent in viewModel.draft.content = .sshKey(newContent) }
            ))
        }
    }

    // MARK: - Discard logic

    /// Handles both the Discard button press and the Esc key.
    ///
    /// - If no changes have been made: dismiss immediately without a prompt (spec §8.3 "no changes" scenario).
    /// - If unsaved changes exist: show the confirmation alert first (spec §8.3 "with changes" scenario).
    private func handleDiscard() {
        if viewModel.hasChanges {
            showingDiscardAlert = true
        } else {
            viewModel.discard()
        }
    }
}
