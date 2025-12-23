import Foundation
@testable import Luego

@MainActor
final class MockSaveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var lastEphemeralArticle: EphemeralArticle?
    var articleToReturn: Article?

    func execute(ephemeralArticle: EphemeralArticle) async throws -> Article {
        executeCallCount += 1
        lastEphemeralArticle = ephemeralArticle
        if shouldThrow {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        return articleToReturn ?? Article(
            url: ephemeralArticle.url,
            title: ephemeralArticle.title,
            content: ephemeralArticle.content,
            thumbnailURL: ephemeralArticle.thumbnailURL,
            publishedDate: ephemeralArticle.publishedDate
        )
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        lastEphemeralArticle = nil
        articleToReturn = nil
    }
}
