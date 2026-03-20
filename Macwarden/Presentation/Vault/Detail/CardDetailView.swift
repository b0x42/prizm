import SwiftUI

// MARK: - CardDetailView

/// Detail view for Card items.
///
/// Displays cardholder name, masked card number, brand, expiry MM/YYYY,
/// masked security code, notes, and custom fields.
struct CardDetailView: View {

    let item:   VaultItem
    let card:   CardContent
    let onCopy: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let name = card.cardholderName {
                    FieldRowView(label: "Cardholder Name", value: name, itemId: item.id, onCopy: onCopy)
                    Divider()
                }

                if let brand = card.brand {
                    FieldRowView(label: "Brand", value: brand, itemId: item.id, onCopy: onCopy)
                    Divider()
                }

                if let number = card.number {
                    FieldRowView(
                        label: "Card Number", value: number,
                        itemId: item.id, isMasked: true, onCopy: onCopy
                    )
                    Divider()
                }

                if card.expMonth != nil || card.expYear != nil {
                    let expiry = [card.expMonth, card.expYear]
                        .compactMap { $0 }
                        .joined(separator: "/")
                    FieldRowView(label: "Expiration", value: expiry, itemId: item.id, onCopy: onCopy)
                    Divider()
                }

                if let code = card.code {
                    FieldRowView(
                        label: "Security Code", value: code,
                        itemId: item.id, isMasked: true, onCopy: onCopy
                    )
                    Divider()
                }

                if let notes = card.notes, !notes.isEmpty {
                    FieldRowView(label: "Notes", value: notes, itemId: item.id, onCopy: onCopy)
                    Divider()
                }

                CustomFieldsSection(fields: card.customFields, itemId: item.id, onCopy: onCopy)
            }
            .padding(.horizontal, 8)
        }
    }
}
