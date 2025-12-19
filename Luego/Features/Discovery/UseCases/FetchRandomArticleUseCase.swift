import Foundation

protocol FetchRandomArticleUseCaseProtocol: Sendable {
    func execute() async throws -> EphemeralArticle
    func execute(onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle
    func clearCache()
}

enum DiscoveryError: LocalizedError {
    case contentFetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .contentFetchFailed(let underlyingError):
            return "Could not load article content: \(underlyingError.localizedDescription)"
        }
    }
}

@MainActor
final class FetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol {
    private let smallWebRepository: SmallWebRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        smallWebRepository: SmallWebRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.smallWebRepository = smallWebRepository
        self.metadataRepository = metadataRepository
    }

    func execute() async throws -> EphemeralArticle {
        try await execute(onArticleEntryFetched: { _ in })
    }

    func execute(onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle {
        let articleEntry = try await smallWebRepository.randomArticleEntry()
        await onArticleEntryFetched(articleEntry.articleUrl)
        return try await fetchArticleContent(for: articleEntry)
    }

    func clearCache() {
        smallWebRepository.clearCache()
    }

    private func fetchArticleContent(for articleEntry: SmallWebArticleEntry) async throws -> EphemeralArticle {
        let discoveryTimeoutSeconds: TimeInterval = 10

        do {
            let articleContent = try await metadataRepository.fetchContent(for: articleEntry.articleUrl, timeout: discoveryTimeoutSeconds)
            let domain = articleEntry.articleUrl.host() ?? "Unknown"

            return EphemeralArticle(
                url: articleEntry.articleUrl,
                title: articleContent.title,
                content: articleContent.content,
                thumbnailURL: articleContent.thumbnailURL,
                publishedDate: articleContent.publishedDate,
                feedTitle: domain
            )
        } catch {
            throw DiscoveryError.contentFetchFailed(error)
        }
    }
}
