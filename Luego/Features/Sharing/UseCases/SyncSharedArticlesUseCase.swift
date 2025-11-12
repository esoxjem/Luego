import Foundation

protocol SyncSharedArticlesUseCaseProtocol: Sendable {
    func execute() async throws -> [Article]
}

final class SyncSharedArticlesUseCase: SyncSharedArticlesUseCaseProtocol {
    private let sharedStorageRepository: SharedStorageRepositoryProtocol
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        sharedStorageRepository: SharedStorageRepositoryProtocol,
        articleRepository: ArticleRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.sharedStorageRepository = sharedStorageRepository
        self.articleRepository = articleRepository
        self.metadataRepository = metadataRepository
    }

    func execute() async throws -> [Article] {
        let sharedURLs = await sharedStorageRepository.getSharedURLs()
        guard !sharedURLs.isEmpty else {
            return []
        }

        var newArticles: [Article] = []

        for url in sharedURLs {
            do {
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

                let savedArticle = try await articleRepository.save(article)
                newArticles.append(savedArticle)
            } catch {
                continue
            }
        }

        await sharedStorageRepository.clearSharedURLs()
        return newArticles
    }
}
