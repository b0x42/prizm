import XCTest
@testable import Prizm

/// Tests for `EditVaultItemUseCaseImpl`.
///
/// Task 2.2 introduces this failing test; task 5.3 completes it once
/// `EditVaultItemUseCaseImpl` and `MockVaultRepository.update` are implemented.
@MainActor
final class EditVaultItemUseCaseTests: XCTestCase {

    private var sut: EditVaultItemUseCaseImpl!
    private var mockRepo: MockVaultRepository!

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() async throws {
        try await super.setUp()
        mockRepo = MockVaultRepository()
        sut = EditVaultItemUseCaseImpl(repository: mockRepo)
    }

    // MARK: - Success path

    /// Verifies that `execute(draft:)` delegates to `VaultRepository.update` and returns
    /// the server-confirmed `VaultItem` produced by the repository.
    func test_execute_callsRepositoryUpdate_andReturnsItem() async throws {
        let expectedItem = makeVaultItem(name: "Updated Name")
        mockRepo.stubbedUpdateResult = expectedItem

        let draft = DraftVaultItem(makeVaultItem(name: "Original Name"))
        let result = try await sut.execute(draft: draft)

        XCTAssertEqual(result, expectedItem)
        XCTAssertEqual(mockRepo.updateCallCount, 1)
        XCTAssertEqual(mockRepo.lastUpdatedDraft?.name, "Original Name")
    }

    // MARK: - Error path

    /// Verifies that errors thrown by the repository propagate out of the use case.
    func test_execute_repositoryThrows_rethrowsError() async {
        mockRepo.stubbedUpdateError = VaultError.itemNotFound("id-1")

        let draft = DraftVaultItem(makeVaultItem(name: "Name"))

        do {
            _ = try await sut.execute(draft: draft)
            XCTFail("Expected error to be thrown")
        } catch let error as VaultError {
            if case .itemNotFound(let id) = error {
                XCTAssertEqual(id, "id-1")
            } else {
                XCTFail("Expected .itemNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeVaultItem(name: String) -> VaultItem {
        VaultItem(
            id: "id-1",
            name: name,
            isFavorite: false,
            isDeleted: false,
            creationDate: baseDate,
            revisionDate: baseDate,
            content: .secureNote(SecureNoteContent(notes: "notes", customFields: []))
        )
    }
}
