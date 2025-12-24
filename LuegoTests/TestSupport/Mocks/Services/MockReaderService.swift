import Foundation
@testable import Luego

@MainActor
final class MockReaderService: ReaderServiceProtocol {
    var fetchContentCallCount = 0
    var updateReadPositionCallCount = 0

    var lastFetchedArticle: Article?
    var lastForceRefresh: Bool?
    var lastUpdatedArticleId: UUID?
    var lastUpdatedPosition: Double?

    var articleToReturn: Article?
    var shouldThrowOnFetchContent = false
    var shouldThrowOnUpdateReadPosition = false

    enum MockError: Error {
        case mockError
    }

    func fetchContent(for article: Article, forceRefresh: Bool) async throws -> Article {
        fetchContentCallCount += 1
        lastFetchedArticle = article
        lastForceRefresh = forceRefresh
        if shouldThrowOnFetchContent {
            throw MockError.mockError
        }
        if let articleToReturn {
            return articleToReturn
        }
        article.content = "Mock content"
        return article
    }

    func updateReadPosition(articleId: UUID, position: Double) async throws {
        updateReadPositionCallCount += 1
        lastUpdatedArticleId = articleId
        lastUpdatedPosition = position
        if shouldThrowOnUpdateReadPosition {
            throw MockError.mockError
        }
    }
}
