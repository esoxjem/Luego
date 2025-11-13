import Foundation

protocol FetchArticleContentUseCaseProtocol: Sendable {
    func execute(article: Article, forceRefresh: Bool) async throws -> Article
}

@MainActor
final class FetchArticleContentUseCase: FetchArticleContentUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        articleRepository: ArticleRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.articleRepository = articleRepository
        self.metadataRepository = metadataRepository
    }

    func execute(article: Article, forceRefresh: Bool = false) async throws -> Article {
        guard forceRefresh || article.content == nil else {
            return article
        }

        let content = try await metadataRepository.fetchContent(for: article.url)
        article.content = content.content

        try await articleRepository.update(article)
        return article
    }
}
