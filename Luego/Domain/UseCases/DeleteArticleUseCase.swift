import Foundation

protocol DeleteArticleUseCase: Sendable {
    func execute(articleId: UUID) async throws
}

final class DefaultDeleteArticleUseCase: DeleteArticleUseCase {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute(articleId: UUID) async throws {
        try await articleRepository.delete(id: articleId)
    }
}
