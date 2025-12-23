import Testing
import Foundation
@testable import Luego

@Suite("UpdateArticleReadPositionUseCase Tests")
@MainActor
struct UpdateArticleReadPositionUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var useCase: UpdateArticleReadPositionUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        useCase = UpdateArticleReadPositionUseCase(articleRepository: mockArticleRepository)
    }

    @Test("execute calls repository with correct articleId and position")
    func executeCallsRepositoryWithCorrectParams() async throws {
        let articleId = UUID()
        let position = 0.75

        try await useCase.execute(articleId: articleId, position: position)

        #expect(mockArticleRepository.updateReadPositionCallCount == 1)
        #expect(mockArticleRepository.lastReadPositionUpdate?.articleId == articleId)
        #expect(mockArticleRepository.lastReadPositionUpdate?.position == position)
    }

    @Test("execute propagates repository errors")
    func executePropagatesErrors() async throws {
        mockArticleRepository.shouldThrowOnUpdateReadPosition = true
        let articleId = UUID()

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(articleId: articleId, position: 0.5)
        }
    }

    @Test("execute handles position at zero")
    func executeHandlesZeroPosition() async throws {
        let articleId = UUID()

        try await useCase.execute(articleId: articleId, position: 0.0)

        #expect(mockArticleRepository.lastReadPositionUpdate?.position == 0.0)
    }

    @Test("execute handles position at one")
    func executeHandlesOnePosition() async throws {
        let articleId = UUID()

        try await useCase.execute(articleId: articleId, position: 1.0)

        #expect(mockArticleRepository.lastReadPositionUpdate?.position == 1.0)
    }

    @Test("execute handles fractional positions")
    func executeHandlesFractionalPosition() async throws {
        let articleId = UUID()

        try await useCase.execute(articleId: articleId, position: 0.333)

        #expect(mockArticleRepository.lastReadPositionUpdate?.position == 0.333)
    }
}
