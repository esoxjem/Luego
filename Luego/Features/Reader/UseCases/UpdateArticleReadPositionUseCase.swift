import Foundation

protocol UpdateArticleReadPositionUseCaseProtocol: Sendable {
    func execute(articleId: UUID, position: Double) async throws
}

final class UpdateArticleReadPositionUseCase: UpdateArticleReadPositionUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute(articleId: UUID, position: Double) async throws {
        try await articleRepository.updateReadPosition(articleId: articleId, position: position)
    }
}
