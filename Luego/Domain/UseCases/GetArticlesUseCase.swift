import Foundation

protocol GetArticlesUseCase: Sendable {
    func execute() async throws -> [Domain.Article]
}

final class DefaultGetArticlesUseCase: GetArticlesUseCase {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute() async throws -> [Domain.Article] {
        try await articleRepository.getAll()
    }
}
