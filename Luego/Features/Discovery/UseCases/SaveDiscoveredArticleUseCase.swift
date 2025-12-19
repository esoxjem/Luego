import Foundation

protocol SaveDiscoveredArticleUseCaseProtocol: Sendable {
    func execute(ephemeralArticle: EphemeralArticle) async throws -> Article
}

@MainActor
final class SaveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol

    init(articleRepository: ArticleRepositoryProtocol) {
        self.articleRepository = articleRepository
    }

    func execute(ephemeralArticle: EphemeralArticle) async throws -> Article {
        let article = Article(
            url: ephemeralArticle.url,
            title: ephemeralArticle.title,
            content: ephemeralArticle.content,
            thumbnailURL: ephemeralArticle.thumbnailURL,
            publishedDate: ephemeralArticle.publishedDate
        )

        return try await articleRepository.save(article)
    }
}
