import SwiftUI

// MARK: - SSHKeyDetailView

/// Detail view for SSH Key items (FR-047).
///
/// Public key and fingerprint are displayed as visible text.
/// Private key is masked by default and revealable on explicit user action.
/// "[No fingerprint]" placeholder is shown when the fingerprint field is absent or empty.
///
/// Fields are grouped into a "Key" card. Notes and Custom Fields sections
/// are hidden when empty.
struct SSHKeyDetailView: View {

    let item:   VaultItem
    let sshKey: SSHKeyContent
    let onCopy: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("Key") {
                    // Public key — visible
                    if let publicKey = sshKey.publicKey {
                        FieldRowView(
                            label:  "Public Key",
                            value:  publicKey,
                            itemId: item.id,
                            onCopy: onCopy
                        )
                        Divider()
                    }

                    // Fingerprint — visible; "[No fingerprint]" placeholder (FR-047)
                    let hasFingerprint = sshKey.keyFingerprint?.isEmpty == false
                    let fingerprint = hasFingerprint ? sshKey.keyFingerprint! : "[No fingerprint]"
                    FieldRowView(
                        label:  "Fingerprint",
                        value:  fingerprint,
                        itemId: item.id,
                        onCopy: hasFingerprint ? onCopy : { _ in }
                    )

                    // Private key — masked
                    if let privateKey = sshKey.privateKey {
                        Divider()
                        FieldRowView(
                            label:    "Private Key",
                            value:    privateKey,
                            itemId:   item.id,
                            isMasked: true,
                            onCopy:   onCopy
                        )
                    }
                }

                if let notes = sshKey.notes, !notes.isEmpty {
                    DetailSectionCard("Notes") {
                        FieldRowView(label: "Notes", value: notes, itemId: item.id, onCopy: onCopy)
                    }
                }

                if !sshKey.customFields.isEmpty {
                    DetailSectionCard("Custom Fields") {
                        CustomFieldsSection(fields: sshKey.customFields, itemId: item.id, onCopy: onCopy)
                    }
                }
            }
        }
    }
}
