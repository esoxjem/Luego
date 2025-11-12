import Foundation

protocol GetArticlesUseCase: Sendable {
    func execute() async throws -> [Article]
}

final class DefaultGetArticlesUseCase: GetArticlesUseCase {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute() async throws -> [Article] {
        try await articleRepository.getAll()
    }
}
