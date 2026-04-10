import SwiftUI

// MARK: - SecureNoteDetailView

/// Detail view for Secure Note items.
///
/// Displays the note body in a "Note" card and any custom fields in a
/// "Custom Fields" card. Both sections are hidden when their content is empty.
struct SecureNoteDetailView: View {

    let item:       VaultItem
    let secureNote: SecureNoteContent
    let onCopy:     (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

                if let notes = secureNote.notes, !notes.isEmpty {
                    DetailSectionCard("Note") {
                        FieldRowView(label: "", value: notes, itemId: item.id, isMultiLine: true, onCopy: onCopy)
                    }
                }

                if !secureNote.customFields.isEmpty {
                    DetailSectionCard("Custom Fields") {
                        CustomFieldsSection(
                            fields: secureNote.customFields,
                            itemId: item.id,
                            onCopy: onCopy
                        )
                    }
                }
            }
    }
}
