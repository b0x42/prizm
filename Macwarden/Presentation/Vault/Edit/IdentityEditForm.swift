import SwiftUI

// MARK: - IdentityEditForm

/// Edit form for Identity vault items.
///
/// Groups the 17+ identity fields into the same six card sections as `IdentityDetailView`
/// so the edit layout is consistent with the read-only view: Personal Info, ID Numbers,
/// Contact, Address, Notes, Custom Fields.
struct IdentityEditForm: View {

    @Binding var draft: DraftIdentityContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("Personal Info") {
                    OptionalEditFieldRow(label: "Title",       value: $draft.title)
                    Divider()
                    OptionalEditFieldRow(label: "First Name",  value: $draft.firstName)
                    Divider()
                    OptionalEditFieldRow(label: "Middle Name", value: $draft.middleName)
                    Divider()
                    OptionalEditFieldRow(label: "Last Name",   value: $draft.lastName)
                    Divider()
                    OptionalEditFieldRow(label: "Company",     value: $draft.company)
                }

                DetailSectionCard("ID Numbers") {
                    OptionalEditFieldRow(label: "SSN",             value: $draft.ssn)
                    Divider()
                    OptionalEditFieldRow(label: "Passport Number", value: $draft.passportNumber)
                    Divider()
                    OptionalEditFieldRow(label: "License Number",  value: $draft.licenseNumber)
                }

                DetailSectionCard("Contact") {
                    OptionalEditFieldRow(label: "Email",    value: $draft.email)
                    Divider()
                    OptionalEditFieldRow(label: "Phone",    value: $draft.phone)
                    Divider()
                    OptionalEditFieldRow(label: "Username", value: $draft.username)
                }

                DetailSectionCard("Address") {
                    OptionalEditFieldRow(label: "Address Line 1", value: $draft.address1)
                    Divider()
                    OptionalEditFieldRow(label: "Address Line 2", value: $draft.address2)
                    Divider()
                    OptionalEditFieldRow(label: "Address Line 3", value: $draft.address3)
                    Divider()
                    OptionalEditFieldRow(label: "City",         value: $draft.city)
                    Divider()
                    OptionalEditFieldRow(label: "State",        value: $draft.state)
                    Divider()
                    OptionalEditFieldRow(label: "Postal Code",  value: $draft.postalCode)
                    Divider()
                    OptionalEditFieldRow(label: "Country",      value: $draft.country)
                }

                DetailSectionCard("Notes") {
                    OptionalEditFieldRow(label: "Notes", value: $draft.notes)
                }

                CustomFieldsEditSection(fields: $draft.customFields)
            }
        }
    }
}
