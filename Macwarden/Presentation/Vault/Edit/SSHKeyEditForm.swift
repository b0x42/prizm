import SwiftUI

// MARK: - SSHKeyEditForm

/// Edit form for SSH Key vault items.
///
/// Private key is masked by default (same treatment as Login password and Hidden
/// custom fields — spec §4.9). Key fingerprint is read-only: it is auto-derived
/// from the private key by the server and is not sent in the PUT request body.
struct SSHKeyEditForm: View {

    @Binding var draft: DraftSSHKeyContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("SSH Key") {
                    // Private key is sensitive — masked by default with reveal toggle.
                    MaskedEditFieldRow(label: "Private Key", value: $draft.privateKey, generatorBinding: $draft.privateKey)
                    Divider()
                    OptionalEditFieldRow(label: "Public Key", value: $draft.publicKey)
                    Divider()
                    // Key fingerprint is server-derived; shown for reference only.
                    readOnlyFingerprintRow
                }

                DetailSectionCard("Notes") {
                    OptionalEditFieldRow(label: "Notes", value: $draft.notes)
                }

                CustomFieldsEditSection(fields: $draft.customFields)
            }
        }
    }

    @ViewBuilder
    private var readOnlyFingerprintRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Key Fingerprint")
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)
                Text(draft.keyFingerprint ?? "—")
                    .font(Typography.fieldValue.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }
}
