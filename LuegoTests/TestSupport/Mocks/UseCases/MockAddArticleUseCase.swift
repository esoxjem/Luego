import Foundation
@testable import Luego

@MainActor
final class MockAddArticleUseCase: AddArticleUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var errorToThrow: Error = ArticleMetadataError.invalidURL
    var articleToReturn: Article?
    var lastURL: URL?

    func execute(url: URL) async throws -> Article {
        executeCallCount += 1
        lastURL = url
        if shouldThrow {
            throw errorToThrow
        }
        return articleToReturn ?? ArticleFixtures.createArticle(url: url)
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        errorToThrow = ArticleMetadataError.invalidURL
        articleToReturn = nil
        lastURL = nil
    }
}
