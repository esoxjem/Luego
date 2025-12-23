import Foundation
@testable import Luego

@MainActor
final class MockDeleteArticleUseCase: DeleteArticleUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var lastDeletedId: UUID?

    func execute(articleId: UUID) async throws {
        executeCallCount += 1
        lastDeletedId = articleId
        if shouldThrow {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        lastDeletedId = nil
    }
}
