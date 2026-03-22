import SwiftUI

// MARK: - CardDetailView

/// Detail view for Card items.
///
/// Payment card fields are grouped into a "Card Details" section.
/// Notes and Custom Fields sections are hidden when empty.
struct CardDetailView: View {

    let item:   VaultItem
    let card:   CardContent
    let onCopy: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("Card Details") {
                    // Each Divider is guarded by whether any field above it is
                    // present — preventing a dangling separator at the card top
                    // when cardholderName is nil.
                    if let name = card.cardholderName {
                        FieldRowView(label: "Cardholder Name", value: name, itemId: item.id, onCopy: onCopy)
                    }
                    if let brand = card.brand {
                        if card.cardholderName != nil { Divider() }
                        FieldRowView(label: "Brand", value: brand, itemId: item.id, onCopy: onCopy)
                    }
                    if let number = card.number {
                        if card.cardholderName != nil || card.brand != nil { Divider() }
                        FieldRowView(
                            label: "Card Number", value: number,
                            itemId: item.id, isMasked: true, onCopy: onCopy
                        )
                    }
                    if card.expMonth != nil || card.expYear != nil {
                        let expiry = [card.expMonth, card.expYear]
                            .compactMap { $0 }
                            .joined(separator: "/")
                        if card.cardholderName != nil || card.brand != nil || card.number != nil { Divider() }
                        FieldRowView(label: "Expiration", value: expiry, itemId: item.id, onCopy: onCopy)
                    }
                    if let code = card.code {
                        if card.cardholderName != nil || card.brand != nil
                            || card.number != nil || card.expMonth != nil || card.expYear != nil { Divider() }
                        FieldRowView(
                            label: "Security Code", value: code,
                            itemId: item.id, isMasked: true, onCopy: onCopy
                        )
                    }
                }

                if let notes = card.notes, !notes.isEmpty {
                    DetailSectionCard("Notes") {
                        FieldRowView(label: "Notes", value: notes, itemId: item.id, onCopy: onCopy)
                    }
                }

                if !card.customFields.isEmpty {
                    DetailSectionCard("Custom Fields") {
                        CustomFieldsSection(fields: card.customFields, itemId: item.id, onCopy: onCopy)
                    }
                }
            }
        }
    }
}
