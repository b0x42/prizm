import SwiftUI

// MARK: - SSHKeyDetailView

/// Detail view for SSH Key items (FR-047).
///
/// Public key and fingerprint are displayed as visible text.
/// Private key is masked by default and revealable on explicit user action.
/// "[No fingerprint]" placeholder is shown when the fingerprint field is absent or empty.
struct SSHKeyDetailView: View {

    let item:   VaultItem
    let sshKey: SSHKeyContent
    let onCopy: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
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
                Divider()

                // Private key — masked
                if let privateKey = sshKey.privateKey {
                    FieldRowView(
                        label:    "Private Key",
                        value:    privateKey,
                        itemId:   item.id,
                        isMasked: true,
                        onCopy:   onCopy
                    )
                    Divider()
                }

                if let notes = sshKey.notes, !notes.isEmpty {
                    FieldRowView(label: "Notes", value: notes, itemId: item.id, onCopy: onCopy)
                    Divider()
                }

                CustomFieldsSection(fields: sshKey.customFields, itemId: item.id, onCopy: onCopy)
            }
            .padding(.horizontal, 8)
        }
    }
}
