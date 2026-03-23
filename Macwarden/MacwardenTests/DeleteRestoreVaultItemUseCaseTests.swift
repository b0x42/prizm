import XCTest
@testable import Macwarden

// MARK: - DeleteRestoreVaultItemUseCaseTests

/// Unit tests for `DeleteVaultItemUseCaseImpl`, `RestoreVaultItemUseCaseImpl`,
/// and `EmptyTrashUseCaseImpl`.
///
/// Each use case is a thin delegate — tests verify correct delegation to the
/// repository and that errors propagate correctly.
@MainActor
final class DeleteRestoreVaultItemUseCaseTests: XCTestCase {

    private var mockRepo: MockVaultRepository!
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() async throws {
        try await super.setUp()
        mockRepo = MockVaultRepository()
    }

    // MARK: - DeleteVaultItemUseCase

    func test_delete_delegatesToRepository() async throws {
        let sut = DeleteVaultItemUseCaseImpl(repository: mockRepo)
        try await sut.execute(id: "abc")

        XCTAssertEqual(mockRepo.deleteCallCount, 1)
        XCTAssertEqual(mockRepo.lastDeletedId, "abc")
    }

    func test_delete_repositoryThrows_rethrowsError() async {
        mockRepo.stubbedDeleteError = APIError.httpError(statusCode: 500, body: "error")
        let sut = DeleteVaultItemUseCaseImpl(repository: mockRepo)

        do {
            try await sut.execute(id: "abc")
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            guard case .httpError(let code, _) = error else {
                return XCTFail("Expected .httpError, got \(error)")
            }
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - RestoreVaultItemUseCase

    func test_restore_delegatesToRepository() async throws {
        let sut = RestoreVaultItemUseCaseImpl(repository: mockRepo)
        try await sut.execute(id: "xyz")

        XCTAssertEqual(mockRepo.restoreCallCount, 1)
        XCTAssertEqual(mockRepo.lastRestoredId, "xyz")
    }

    func test_restore_repositoryThrows_rethrowsError() async {
        mockRepo.stubbedRestoreError = APIError.httpError(statusCode: 404, body: "not found")
        let sut = RestoreVaultItemUseCaseImpl(repository: mockRepo)

        do {
            try await sut.execute(id: "xyz")
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            guard case .httpError(let code, _) = error else {
                return XCTFail("Expected .httpError, got \(error)")
            }
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - EmptyTrashUseCase

    func test_emptyTrash_delegatesToRepository() async throws {
        let sut = EmptyTrashUseCaseImpl(repository: mockRepo)
        try await sut.execute()

        XCTAssertEqual(mockRepo.emptyTrashCallCount, 1)
    }

    func test_emptyTrash_repositoryThrows_rethrowsError() async {
        mockRepo.stubbedEmptyTrashError = APIError.httpError(statusCode: 503, body: "unavailable")
        let sut = EmptyTrashUseCaseImpl(repository: mockRepo)

        do {
            try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            guard case .httpError(let code, _) = error else {
                return XCTFail("Expected .httpError, got \(error)")
            }
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
