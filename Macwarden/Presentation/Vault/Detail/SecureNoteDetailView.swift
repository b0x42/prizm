import SwiftUI

// MARK: - SecureNoteDetailView

/// Detail view for Secure Note items.
///
/// Displays the note body (copyable) and any custom fields.
struct SecureNoteDetailView: View {

    let item:       VaultItem
    let secureNote: SecureNoteContent
    let onCopy:     (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let notes = secureNote.notes, !notes.isEmpty {
                    FieldRowView(label: "Notes", value: notes, itemId: item.id, onCopy: onCopy)
                    Divider()
                }
                CustomFieldsSection(
                    fields: secureNote.customFields,
                    itemId: item.id,
                    onCopy: onCopy
                )
            }
            .padding(.horizontal, 8)
        }
    }
}
