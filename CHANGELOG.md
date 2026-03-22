# Changelog

All notable changes to Macwarden are documented here.

## Unreleased

### Changed

- **Item detail grouped view**: Vault item detail fields are now grouped into labelled card sections (`DetailSectionCard`) for all five item types — Login (Credentials, Websites, Notes, Custom Fields), Card (Card Details, Notes, Custom Fields), Identity (Personal Info, ID Numbers, Contact, Address, Notes, Custom Fields), Secure Note (Note, Custom Fields), and SSH Key (Key, Notes, Custom Fields). Empty sections are hidden. The `CardBackground` `ViewModifier` provides the rounded-corner, adaptive-background, shadow card appearance.
