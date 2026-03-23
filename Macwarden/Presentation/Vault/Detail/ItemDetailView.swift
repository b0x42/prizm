import SwiftUI

// MARK: - ItemDetailView

/// Routes to the correct type-specific detail view and shows item metadata footer.
///
/// FR-031: creation + revision dates in the footer.
/// FR-034: "No item selected" empty state when `item` is nil.
/// edit-vault-items: Edit toolbar button + sheet presentation.
struct ItemDetailView: View {

    let item:              VaultItem?
    let faviconLoader:     FaviconLoader
    let onCopy:            (String) -> Void
    /// Factory that creates an `ItemEditViewModel` for the given item.
    /// Passed from `VaultBrowserView` so this view stays decoupled from `AppContainer`.
    let makeEditViewModel: (VaultItem) -> ItemEditViewModel
    /// Called when the edit sheet opens (`true`) or closes (`false`).
    /// Drives `MenuBarViewModel.canEdit` / `canSave` state (task 9.5).
    var onEditSheetChanged: ((Bool) -> Void)? = nil

    /// Incremented by `VaultBrowserViewModel.triggerEdit()` when the "Item > Edit" menu bar
    /// action fires (spec §9.3). `.onChange` opens the edit sheet for the current item.
    var editTrigger: Int = 0

    /// Incremented by `VaultBrowserViewModel.triggerSave()` when the "Item > Save" menu bar
    /// action fires (spec §9.4). `.onChange` calls `save()` on the active edit ViewModel.
    var saveTrigger: Int = 0

    /// Tracks whether the edit sheet is currently presented.
    @State private var isEditSheetPresented = false
    /// The ViewModel for the active edit session. Created on Edit button press and
    /// released (nil'd) when the sheet is dismissed to clear the draft from memory (§III).
    @State private var editViewModel: ItemEditViewModel?

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                // Item name header with favicon/type icon
                HStack(alignment: .center, spacing: 12) {
                    FaviconView(
                        domain:   primaryDomain(for: item),
                        itemType: itemType(for: item),
                        loader:   faviconLoader,
                        size:     36
                    )
                    Text(item.name.isEmpty ? " " : item.name)
                        .font(Typography.pageTitle)
                        .accessibilityIdentifier(AccessibilityID.Detail.itemName)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.pageTop)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, Spacing.pageHeaderBottom)

                // Type-specific content
                typeDetailView(for: item)

                Divider()

                // Metadata footer (FR-031)
                HStack {
                    Label(
                        "Created \(item.creationDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar"
                    )
                    .font(Typography.utility)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Label(
                        "Updated \(item.revisionDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "clock"
                    )
                    .font(Typography.utility)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // Edit button — visible only when an item is selected (this branch).
                    // ⌘E shortcut fires only when the button is enabled (sheet not open).
                    // spec §8.5, §8.7
                    Button("Edit") {
                        openEditSheet(for: item)
                    }
                    .disabled(isEditSheetPresented)
                    .keyboardShortcut("e", modifiers: .command)
                    .accessibilityIdentifier(AccessibilityID.Edit.editButton)
                }
            }
            .sheet(isPresented: $isEditSheetPresented, onDismiss: {
                editViewModel = nil
                onEditSheetChanged?(false)
            }) {
                if let vm = editViewModel {
                    ItemEditView(viewModel: vm, isPresented: $isEditSheetPresented)
                }
            }
            // Menu bar "Edit" action — mirrors the toolbar Edit button (spec §9.3).
            .onChangeCompat(of: editTrigger) { openEditSheet(for: item) }
            // Menu bar "Save" action — mirrors the in-sheet Save button (spec §9.4).
            // `ItemEditViewModel.save()` is a no-op if `canSave` is false, so this is safe
            // even when called while the name is blank or a save is already in-flight.
            .onChangeCompat(of: saveTrigger) { editViewModel?.save() }
        } else {
            ContentUnavailableView(
                "No Item Selected",
                systemImage: "square.dashed",
                description: Text("Select an item from the list.")
            )
            .accessibilityIdentifier(AccessibilityID.Detail.emptyState)
        }
    }

    // MARK: - Edit sheet

    private func openEditSheet(for item: VaultItem) {
        guard !isEditSheetPresented else { return }
        let vm = makeEditViewModel(item)
        editViewModel = vm
        isEditSheetPresented = true
        onEditSheetChanged?(true)
    }

    // MARK: - Favicon helpers

    private func primaryDomain(for item: VaultItem) -> String? {
        guard case .login(let l) = item.content,
              let first = l.uris.first else { return nil }
        return URL(string: first.uri)?.host
    }

    private func itemType(for item: VaultItem) -> ItemType {
        switch item.content {
        case .login:      return .login
        case .card:       return .card
        case .identity:   return .identity
        case .secureNote: return .secureNote
        case .sshKey:     return .sshKey
        }
    }

    // MARK: - Type dispatcher
    @ViewBuilder
    private func typeDetailView(for item: VaultItem) -> some View {
        switch item.content {
        case .login(let l):
            LoginDetailView(item: item, login: l, onCopy: onCopy)

        case .card(let c):
            CardDetailView(item: item, card: c, onCopy: onCopy)

        case .identity(let i):
            IdentityDetailView(item: item, identity: i, onCopy: onCopy)

        case .secureNote(let n):
            SecureNoteDetailView(item: item, secureNote: n, onCopy: onCopy)

        case .sshKey(let k):
            SSHKeyDetailView(item: item, sshKey: k, onCopy: onCopy)
        }
    }
}

// MARK: - macOS version compat

private extension View {
    /// Calls `action` when `value` changes, without deprecation warnings on either target OS.
    ///
    /// macOS 14 deprecated `onChange(of:perform:)` (single-arg closure) in favour of a
    /// zero-arg form. macOS 13 only has the single-arg form. Branching on `#available`
    /// keeps both OS versions happy at the two call sites in this file.
    @ViewBuilder
    func onChangeCompat<T: Equatable>(of value: T, action: @escaping () -> Void) -> some View {
        if #available(macOS 14, *) {
            self.onChange(of: value, action)
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }
}
