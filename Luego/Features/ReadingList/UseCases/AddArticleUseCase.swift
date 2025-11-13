import Foundation

protocol AddArticleUseCaseProtocol: Sendable {
    func execute(url: URL) async throws -> Article
}

@MainActor
final class AddArticleUseCase: AddArticleUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        articleRepository: ArticleRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.articleRepository = articleRepository
        self.metadataRepository = metadataRepository
    }

    func execute(url: URL) async throws -> Article {
        let validatedURL = try await metadataRepository.validateURL(url)
        let metadata = try await metadataRepository.fetchMetadata(for: validatedURL)

        let article = Article(
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
