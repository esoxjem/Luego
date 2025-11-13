import Foundation

protocol FetchArticleContentUseCaseProtocol: Sendable {
    func execute(article: Article) async throws -> Article
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

    func execute(article: Article) async throws -> Article {
        guard article.content == nil else {
            return article
        }

        let content = try await metadataRepository.fetchContent(for: article.url)
        article.content = content.content

        try await articleRepository.update(article)
        return article
    }
}
