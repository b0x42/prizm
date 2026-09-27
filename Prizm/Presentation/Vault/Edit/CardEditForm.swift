import SwiftUI

// MARK: - CardEditForm

/// Edit form for Card vault items.
///
/// Mirrors the layout of `CardDetailView`. All card fields are editable text fields.
struct CardEditForm: View {

    @Binding var draft: DraftCardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            DetailSectionCard("Card Details") {
                OptionalEditFieldRow(label: "Cardholder Name", value: $draft.cardholderName)
                Divider()
                OptionalEditFieldRow(label: "Brand", value: $draft.brand)
                Divider()
                MaskedEditFieldRow(label: "Number", value: $draft.number)
                Divider()
                OptionalEditFieldRow(label: "Expiry Month", value: $draft.expMonth)
                Divider()
                OptionalEditFieldRow(label: "Expiry Year", value: $draft.expYear)
                Divider()
                MaskedEditFieldRow(label: "Security Code", value: $draft.code)
            }

            DetailSectionCard("Notes") {
                OptionalEditFieldRow(label: "Notes", value: $draft.notes)
            }
        }
    }
}
