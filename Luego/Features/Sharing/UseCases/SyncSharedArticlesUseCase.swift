import Foundation
import os

protocol SyncSharedArticlesUseCaseProtocol: Sendable {
    func execute() async throws -> [Article]
}

@MainActor
final class SyncSharedArticlesUseCase: SyncSharedArticlesUseCaseProtocol {
    private let sharedStorageRepository: SharedStorageRepositoryProtocol
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol
    private let logger = Logger(subsystem: "com.esoxjem.Luego", category: "SyncSharedArticles")

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
                logger.error("Failed to sync shared article from \(url.absoluteString): \(error.localizedDescription)")
                continue
            }
        }

        await sharedStorageRepository.clearSharedURLs()
        return newArticles
    }
}
