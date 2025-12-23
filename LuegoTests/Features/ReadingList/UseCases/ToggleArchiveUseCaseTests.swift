import Testing
import Foundation
@testable import Luego

@Suite("ToggleArchiveUseCase Tests")
@MainActor
struct ToggleArchiveUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var useCase: ToggleArchiveUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        useCase = ToggleArchiveUseCase(articleRepository: mockArticleRepository)
    }

    @Test("execute calls repository toggleArchive with correct id")
    func executeCallsRepositoryWithCorrectId() async throws {
        let articleId = UUID()

        try await useCase.execute(articleId: articleId)

        #expect(mockArticleRepository.toggleArchiveCallCount == 1)
        #expect(mockArticleRepository.lastToggledArchiveId == articleId)
    }

    @Test("execute propagates repository errors")
    func executePropagatesErrors() async throws {
        mockArticleRepository.shouldThrowOnToggleArchive = true
        let articleId = UUID()

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(articleId: articleId)
        }
    }

    @Test("execute toggles archive state")
    func executeTogglesArchiveState() async throws {
        let article = ArticleFixtures.createArticle(isArchived: false)
        mockArticleRepository.articles = [article]

        try await useCase.execute(articleId: article.id)

        #expect(mockArticleRepository.articles[0].isArchived == true)
    }
}
