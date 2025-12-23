import Testing
import Foundation
@testable import Luego

@Suite("DeleteArticleUseCase Tests")
@MainActor
struct DeleteArticleUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var useCase: DeleteArticleUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        useCase = DeleteArticleUseCase(articleRepository: mockArticleRepository)
    }

    @Test("execute calls repository delete with correct id")
    func executeCallsRepositoryWithCorrectId() async throws {
        let articleId = UUID()

        try await useCase.execute(articleId: articleId)

        #expect(mockArticleRepository.deleteCallCount == 1)
        #expect(mockArticleRepository.lastDeletedId == articleId)
    }

    @Test("execute propagates repository errors")
    func executePropagatesErrors() async throws {
        mockArticleRepository.shouldThrowOnDelete = true
        let articleId = UUID()

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(articleId: articleId)
        }
    }

    @Test("execute succeeds for non-existent id")
    func executeSucceedsForNonExistentId() async throws {
        let nonExistentId = UUID()

        try await useCase.execute(articleId: nonExistentId)

        #expect(mockArticleRepository.deleteCallCount == 1)
    }
}
