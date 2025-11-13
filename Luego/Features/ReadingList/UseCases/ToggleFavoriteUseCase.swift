import Foundation

protocol ToggleFavoriteUseCaseProtocol: Sendable {
    func execute(articleId: UUID) async throws
}

@MainActor
final class ToggleFavoriteUseCase: ToggleFavoriteUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute(articleId: UUID) async throws {
        try await articleRepository.toggleFavorite(id: articleId)
    }
}
