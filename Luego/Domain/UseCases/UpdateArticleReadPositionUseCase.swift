import Foundation

protocol UpdateArticleReadPositionUseCase: Sendable {
    func execute(articleId: UUID, position: Double) async throws
}

final class DefaultUpdateArticleReadPositionUseCase: UpdateArticleReadPositionUseCase {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute(articleId: UUID, position: Double) async throws {
        try await articleRepository.updateReadPosition(articleId: articleId, position: position)
    }
}
