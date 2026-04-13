import XCTest
@testable import Prizm

/// RED tests for task 2.0 — SyncResponse decoding of organizations and collections.
/// These tests FAIL until tasks 2.1–2.4 (RawOrganization, RawCollection, SyncResponse extension,
/// RawCipher.collectionIds) are implemented (Constitution §IV — Red first).
final class SyncResponseOrgDecodingTests: XCTestCase {

    // MARK: - Helpers

    private let decoder = JSONDecoder()

    /// Minimal valid SyncResponse JSON with organizations and collections.
    /// Uses Vaultwarden camelCase field names for cipher/folder fields,
    /// and PascalCase for the top-level array keys (Organizations, Collections)
    /// — matching the FlexKeys approach used in SyncResponse.init(from:).
    private let jsonWithOrgsAndCollections = """
    {
        "Profile": {
            "Id": "user1",
            "Email": "test@example.com",
            "Name": "Test User",
            "Key": "2.abc|def|ghi"
        },
        "Ciphers": [
            {
                "Id": "cipher1",
                "organizationId": "org1",
                "type": 1,
                "name": "2.enc|iv|mac",
                "favorite": false,
                "collectionIds": ["col1", "col2"],
                "revisionDate": "2024-01-01T00:00:00Z"
            }
        ],
        "Folders": [],
        "Organizations": [
            {
                "id": "org1",
                "name": "Acme Corp",
                "key": "4.rsa-enc-key",
                "type": 1
            }
        ],
        "Collections": [
            {
                "id": "col1",
                "organizationId": "org1",
                "name": "2.enc-col-name|iv|mac"
            }
        ]
    }
    """

    /// Minimal valid SyncResponse JSON without organizations or collections keys.
    private let jsonWithoutOrgs = """
    {
        "Profile": {
            "Id": "user1",
            "Email": "test@example.com",
            "Name": "Test User",
            "Key": "2.abc|def|ghi"
        },
        "Ciphers": [],
        "Folders": []
    }
    """

    // MARK: - Organizations decoded

    func testSyncResponse_decodesOrganizations() throws {
        let data = try XCTUnwrap(jsonWithOrgsAndCollections.data(using: .utf8))
        let response = try decoder.decode(SyncResponse.self, from: data)

        XCTAssertEqual(response.organizations.count, 1)
        let org = try XCTUnwrap(response.organizations.first)
        XCTAssertEqual(org.id, "org1")
        XCTAssertEqual(org.name, "Acme Corp")
        XCTAssertEqual(org.key, "4.rsa-enc-key")
        XCTAssertEqual(org.type, 1)
    }

    // MARK: - Collections decoded

    func testSyncResponse_decodesCollections() throws {
        let data = try XCTUnwrap(jsonWithOrgsAndCollections.data(using: .utf8))
        let response = try decoder.decode(SyncResponse.self, from: data)

        XCTAssertEqual(response.collections.count, 1)
        let col = try XCTUnwrap(response.collections.first)
        XCTAssertEqual(col.id, "col1")
        XCTAssertEqual(col.organizationId, "org1")
        XCTAssertEqual(col.name, "2.enc-col-name|iv|mac")
    }

    // MARK: - Absent keys default to []

    func testSyncResponse_absentOrganizationsDefaultsToEmpty() throws {
        let data = try XCTUnwrap(jsonWithoutOrgs.data(using: .utf8))
        let response = try decoder.decode(SyncResponse.self, from: data)

        XCTAssertEqual(response.organizations, [])
    }

    func testSyncResponse_absentCollectionsDefaultsToEmpty() throws {
        let data = try XCTUnwrap(jsonWithoutOrgs.data(using: .utf8))
        let response = try decoder.decode(SyncResponse.self, from: data)

        XCTAssertEqual(response.collections, [])
    }

    // MARK: - RawCipher.collectionIds decoded

    func testRawCipher_decodesCollectionIds() throws {
        let data = try XCTUnwrap(jsonWithOrgsAndCollections.data(using: .utf8))
        let response = try decoder.decode(SyncResponse.self, from: data)

        let cipher = try XCTUnwrap(response.ciphers.first)
        XCTAssertEqual(cipher.collectionIds, ["col1", "col2"])
    }

    func testRawCipher_absentCollectionIdsDefaultsToEmpty() throws {
        let json = """
        {
            "Profile": {"Id":"u","Email":"e","Name":"n","Key":"2.k|k|k"},
            "Ciphers": [{"Id":"c1","Type":1,"Name":"2.n|n|n","Favorite":false,"RevisionDate":"2024-01-01T00:00:00Z"}],
            "Folders": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(SyncResponse.self, from: data)

        let cipher = try XCTUnwrap(response.ciphers.first)
        XCTAssertEqual(cipher.collectionIds, [])
    }
}
