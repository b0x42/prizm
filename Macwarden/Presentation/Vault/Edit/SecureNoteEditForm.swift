import SwiftUI

// MARK: - SecureNoteEditForm

/// Edit form for Secure Note vault items.
///
/// Shows an editable Note text field and the existing custom fields section.
struct SecureNoteEditForm: View {

    @Binding var draft: DraftSecureNoteContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("Note") {
                    OptionalEditFieldRow(label: "Note", value: $draft.notes)
                }

                CustomFieldsEditSection(fields: $draft.customFields)
            }
        }
    }
}
