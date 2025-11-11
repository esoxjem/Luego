import Foundation

protocol FetchArticleContentUseCase: Sendable {
    func execute(article: Domain.Article) async throws -> Domain.Article
}

final class DefaultFetchArticleContentUseCase: FetchArticleContentUseCase {
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        articleRepository: ArticleRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.articleRepository = articleRepository
        self.metadataRepository = metadataRepository
    }

    func execute(article: Domain.Article) async throws -> Domain.Article {
        guard article.content == nil else {
            return article
        }

        let content = try await metadataRepository.fetchContent(for: article.url)

        var updatedArticle = article
        updatedArticle.content = content.content

        try await articleRepository.update(updatedArticle)
        return updatedArticle
    }
}
