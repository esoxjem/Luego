import Foundation

protocol FetchRandomArticleUseCaseProtocol: Sendable {
    func execute() async throws -> EphemeralArticle
    func execute(onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle
    func clearCache()
    func prepareForFetch() -> DiscoverySource
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
    private let source: DiscoverySource
    private let sourceRepository: DiscoverySourceProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        source: DiscoverySource,
        sourceRepository: DiscoverySourceProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.source = source
        self.sourceRepository = sourceRepository
        self.metadataRepository = metadataRepository
    }

    func prepareForFetch() -> DiscoverySource {
        source
    }

    func execute() async throws -> EphemeralArticle {
        try await execute(onArticleEntryFetched: { _ in })
    }

    func execute(onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle {
        let maxRetries = 10
        for _ in 0..<maxRetries {
            let articleEntry = try await sourceRepository.randomArticleEntry()
            if isYouTubeURL(articleEntry.articleUrl) {
                continue
            }
            await onArticleEntryFetched(articleEntry.articleUrl)
            return try await fetchArticleContent(for: articleEntry)
        }
        let articleEntry = try await sourceRepository.randomArticleEntry()
        await onArticleEntryFetched(articleEntry.articleUrl)
        return try await fetchArticleContent(for: articleEntry)
    }

    private func isYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        let youtubeHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"]
        return youtubeHosts.contains(host)
    }

    func clearCache() {
        sourceRepository.clearCache()
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
