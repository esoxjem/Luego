import Foundation
@testable import Luego

@MainActor
final class MockFetchArticleContentUseCase: FetchArticleContentUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var contentToSet: String = "Fetched content for testing purposes."
    var lastArticle: Article?
    var lastForceRefresh: Bool?

    func execute(article: Article, forceRefresh: Bool) async throws -> Article {
        executeCallCount += 1
        lastArticle = article
        lastForceRefresh = forceRefresh
        if shouldThrow {
            throw ArticleMetadataError.noMetadata
        }
        article.content = contentToSet
        return article
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        contentToSet = "Fetched content for testing purposes."
        lastArticle = nil
        lastForceRefresh = nil
    }
}
