import XCTest
@testable import Prizm

/// Unit tests for `Organization.canManageCollections` role gate.
///
/// Spec: org-collections/spec.md — "canManageCollections reflects role"
/// Covers every `OrgRole` case including `.custom` (deny-by-default, §4 of Bitwarden
/// Security Whitepaper — custom-role permission flags are not present in the sync response).
@MainActor
final class OrganizationEntityTests: XCTestCase {

    // MARK: - canManageCollections

    func testOwnerCanManageCollections() {
        let org = Organization(id: "1", name: "Test", role: .owner)
        XCTAssertTrue(org.canManageCollections)
    }

    func testAdminCanManageCollections() {
        let org = Organization(id: "1", name: "Test", role: .admin)
        XCTAssertTrue(org.canManageCollections)
    }

    func testManagerCanManageCollections() {
        let org = Organization(id: "1", name: "Test", role: .manager)
        XCTAssertTrue(org.canManageCollections)
    }

    func testUserCannotManageCollections() {
        let org = Organization(id: "1", name: "Test", role: .user)
        XCTAssertFalse(org.canManageCollections)
    }

    func testCustomRoleCannotManageCollections() {
        // Custom role defaults to false — server-side permission flags for custom roles
        // are not available in the sync `type` integer (Bitwarden Security Whitepaper §4).
        let org = Organization(id: "1", name: "Test", role: .custom)
        XCTAssertFalse(org.canManageCollections)
    }

    // MARK: - OrgRole raw values

    func testOrgRoleRawValues() {
        XCTAssertEqual(OrgRole(rawValue: 0), .owner)
        XCTAssertEqual(OrgRole(rawValue: 1), .admin)
        XCTAssertEqual(OrgRole(rawValue: 2), .user)
        XCTAssertEqual(OrgRole(rawValue: 3), .manager)
        XCTAssertEqual(OrgRole(rawValue: 4), .custom)
    }
}
