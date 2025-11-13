import Foundation

protocol GetArticlesUseCaseProtocol: Sendable {
    func execute() async throws -> [Article]
}

@MainActor
final class GetArticlesUseCase: GetArticlesUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute() async throws -> [Article] {
        try await articleRepository.getAll()
    }
}
