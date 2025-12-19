import Foundation

protocol FetchRandomArticleUseCaseProtocol: Sendable {
    func execute() async throws -> EphemeralArticle
}

enum DiscoveryError: LocalizedError {
    case allAttemptsFailed
    case contentFetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .allAttemptsFailed:
            return "Could not find a working article after multiple attempts"
        case .contentFetchFailed:
            return "Could not load article content"
        }
    }
}

@MainActor
final class FetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol {
    private let smallWebRepository: SmallWebRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol
    private let maxAttempts = 3

    init(
        smallWebRepository: SmallWebRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.smallWebRepository = smallWebRepository
        self.metadataRepository = metadataRepository
    }

    func execute() async throws -> EphemeralArticle {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await fetchRandomArticleFromSmallWeb()
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? DiscoveryError.allAttemptsFailed
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
