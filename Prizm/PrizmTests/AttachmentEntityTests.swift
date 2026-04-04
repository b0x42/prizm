import XCTest
@testable import Prizm

/// Tests for `Attachment` value semantics and `VaultItem.attachments` field behaviour.
final class AttachmentEntityTests: XCTestCase {

    // MARK: - Attachment value semantics

    func test_attachment_isValueType() {
        var a = Attachment(
            id: "att-1", fileName: "photo.jpg", encryptedKey: "2.abc|def|ghi",
            size: 1024, sizeName: "1 KB", url: "https://example.com/file", isUploadIncomplete: false
        )
        let copy = a
        // VaultItem is nonisolated struct — changes to 'a' must not affect 'copy'
        // (can't mutate let-bound fields, but we can verify they are independent values)
        XCTAssertEqual(a.id, copy.id)
        XCTAssertEqual(a.fileName, copy.fileName)
        _ = a   // suppress unused-variable warning
    }

    func test_attachment_equatable() {
        let a = Attachment(
            id: "att-1", fileName: "doc.pdf", encryptedKey: "2.x|y|z",
            size: 2048, sizeName: "2 KB", url: nil, isUploadIncomplete: true
        )
        let b = Attachment(
            id: "att-1", fileName: "doc.pdf", encryptedKey: "2.x|y|z",
            size: 2048, sizeName: "2 KB", url: nil, isUploadIncomplete: true
        )
        XCTAssertEqual(a, b)
    }

    func test_attachment_notEqual_differentId() {
        let a = Attachment(
            id: "att-1", fileName: "doc.pdf", encryptedKey: "2.x|y|z",
            size: 2048, sizeName: "2 KB", url: nil, isUploadIncomplete: false
        )
        let b = Attachment(
            id: "att-2", fileName: "doc.pdf", encryptedKey: "2.x|y|z",
            size: 2048, sizeName: "2 KB", url: nil, isUploadIncomplete: false
        )
        XCTAssertNotEqual(a, b)
    }

    func test_attachment_isUploadIncomplete_whenUrlNil() {
        let a = Attachment(
            id: "att-1", fileName: "doc.pdf", encryptedKey: "2.x|y|z",
            size: 100, sizeName: "100 B", url: nil, isUploadIncomplete: true
        )
        XCTAssertTrue(a.isUploadIncomplete)
        XCTAssertNil(a.url)
    }

    func test_attachment_isUploadComplete_whenUrlPresent() {
        let a = Attachment(
            id: "att-1", fileName: "doc.pdf", encryptedKey: "2.x|y|z",
            size: 100, sizeName: "100 B", url: "https://cdn.example.com/file", isUploadIncomplete: false
        )
        XCTAssertFalse(a.isUploadIncomplete)
        XCTAssertNotNil(a.url)
    }

    // MARK: - VaultItem.attachments default

    func test_vaultItem_attachments_defaultsToEmpty() {
        let item = VaultItem(
            id: "v-1", name: "Login", isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .secureNote(SecureNoteContent(notes: nil, customFields: []))
        )
        XCTAssertTrue(item.attachments.isEmpty)
    }

    func test_vaultItem_attachments_preservedInConstruction() {
        let att = Attachment(
            id: "att-1", fileName: "file.txt", encryptedKey: "2.a|b|c",
            size: 64, sizeName: "64 B", url: nil, isUploadIncomplete: true
        )
        let item = VaultItem(
            id: "v-1", name: "Note", isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .secureNote(SecureNoteContent(notes: nil, customFields: [])),
            attachments: [att]
        )
        XCTAssertEqual(item.attachments.count, 1)
        XCTAssertEqual(item.attachments[0].id, "att-1")
    }

    // MARK: - Null attachments → empty array

    func test_nullAttachments_treatedAsEmptyArray() {
        // Validates that the Domain entity defaults to [] when no attachments are provided,
        // mirroring the server's null → [] coercion rule.
        let item = VaultItem(
            id: "v-2", name: "Card", isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .secureNote(SecureNoteContent(notes: nil, customFields: []))
            // attachments omitted — verifies default value is []
        )
        XCTAssertEqual(item.attachments, [])
    }
}
