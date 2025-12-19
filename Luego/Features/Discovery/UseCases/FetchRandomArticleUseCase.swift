import Foundation

protocol FetchRandomArticleUseCaseProtocol: Sendable {
    func execute() async throws -> EphemeralArticle
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
        try await fetchRandomArticleFromSmallWeb()
    }

    func clearCache() {
        smallWebRepository.clearCache()
    }

    private func fetchRandomArticleFromSmallWeb() async throws -> EphemeralArticle {
        let articleEntry = try await smallWebRepository.randomArticleEntry()

        do {
            let articleContent = try await metadataRepository.fetchContent(for: articleEntry.articleUrl)
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
