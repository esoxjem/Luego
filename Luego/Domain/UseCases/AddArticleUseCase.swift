import Foundation

protocol AddArticleUseCase: Sendable {
    func execute(url: URL) async throws -> Domain.Article
}

final class DefaultAddArticleUseCase: AddArticleUseCase {
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        articleRepository: ArticleRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.articleRepository = articleRepository
        self.metadataRepository = metadataRepository
    }

    func execute(url: URL) async throws -> Domain.Article {
        let validatedURL = try await metadataRepository.validateURL(url)
        let metadata = try await metadataRepository.fetchMetadata(for: validatedURL)

        let article = Domain.Article(
            id: UUID(),
            url: validatedURL,
            title: metadata.title,
            content: nil,
            savedDate: Date(),
            thumbnailURL: metadata.thumbnailURL,
            publishedDate: metadata.publishedDate,
            readPosition: 0
        )

        return try await articleRepository.save(article)
    }
}
