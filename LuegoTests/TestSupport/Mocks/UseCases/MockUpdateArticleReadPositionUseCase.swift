import Foundation
@testable import Luego

@MainActor
final class MockUpdateArticleReadPositionUseCase: UpdateArticleReadPositionUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var lastArticleId: UUID?
    var lastPosition: Double?

    func execute(articleId: UUID, position: Double) async throws {
        executeCallCount += 1
        lastArticleId = articleId
        lastPosition = position
        if shouldThrow {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        lastArticleId = nil
        lastPosition = nil
    }
}
