import Foundation

protocol ToggleArchiveUseCaseProtocol: Sendable {
    func execute(articleId: UUID) async throws
}

@MainActor
final class ToggleArchiveUseCase: ToggleArchiveUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute(articleId: UUID) async throws {
        try await articleRepository.toggleArchive(id: articleId)
    }
}
