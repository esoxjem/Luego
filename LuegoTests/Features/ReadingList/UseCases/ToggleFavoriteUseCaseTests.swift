import Testing
import Foundation
@testable import Luego

@Suite("ToggleFavoriteUseCase Tests")
@MainActor
struct ToggleFavoriteUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var useCase: ToggleFavoriteUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        useCase = ToggleFavoriteUseCase(articleRepository: mockArticleRepository)
    }

    @Test("execute calls repository toggleFavorite with correct id")
    func executeCallsRepositoryWithCorrectId() async throws {
        let articleId = UUID()

        try await useCase.execute(articleId: articleId)

        #expect(mockArticleRepository.toggleFavoriteCallCount == 1)
        #expect(mockArticleRepository.lastToggledFavoriteId == articleId)
    }

    @Test("execute propagates repository errors")
    func executePropagatesErrors() async throws {
        mockArticleRepository.shouldThrowOnToggleFavorite = true
        let articleId = UUID()

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(articleId: articleId)
        }
    }

    @Test("execute toggles favorite state")
    func executeTogglesFavoriteState() async throws {
        let article = ArticleFixtures.createArticle(isFavorite: false)
        mockArticleRepository.articles = [article]

        try await useCase.execute(articleId: article.id)

        #expect(mockArticleRepository.articles[0].isFavorite == true)
    }
}
