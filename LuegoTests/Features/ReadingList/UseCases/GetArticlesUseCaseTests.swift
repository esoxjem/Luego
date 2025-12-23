import Testing
import Foundation
@testable import Luego

@Suite("GetArticlesUseCase Tests")
@MainActor
struct GetArticlesUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var useCase: GetArticlesUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        useCase = GetArticlesUseCase(articleRepository: mockArticleRepository)
    }

    @Test("execute returns articles from repository")
    func executeReturnsArticles() async throws {
        let articles = ArticleFixtures.createMultipleArticles(count: 3)
        mockArticleRepository.articles = articles

        let result = try await useCase.execute()

        #expect(result.count == 3)
        #expect(mockArticleRepository.getAllCallCount == 1)
    }

    @Test("execute returns empty array when no articles")
    func executeReturnsEmptyArray() async throws {
        mockArticleRepository.articles = []

        let result = try await useCase.execute()

        #expect(result.isEmpty)
    }

    @Test("execute propagates repository errors")
    func executePropagatesErrors() async throws {
        mockArticleRepository.shouldThrowOnGetAll = true

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute()
        }
    }
}
