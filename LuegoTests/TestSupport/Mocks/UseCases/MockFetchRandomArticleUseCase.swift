import Foundation
@testable import Luego

@MainActor
final class MockFetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol {
    var executeCallCount = 0
    var executeWithCallbackCallCount = 0
    var clearCacheCallCount = 0
    var prepareForFetchCallCount = 0

    var shouldThrow = false
    var ephemeralArticleToReturn: EphemeralArticle?
    var sourceToReturn: DiscoverySource = .kagiSmallWeb
    var lastCallback: ((URL) -> Void)?

    func execute() async throws -> EphemeralArticle {
        executeCallCount += 1
        if shouldThrow {
            throw DiscoveryError.contentFetchFailed(NSError(domain: "Test", code: 1))
        }
        guard let article = ephemeralArticleToReturn else {
            throw DiscoveryError.contentFetchFailed(NSError(domain: "Test", code: 1))
        }
        return article
    }

    func execute(onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle {
        executeWithCallbackCallCount += 1
        if shouldThrow {
            throw DiscoveryError.contentFetchFailed(NSError(domain: "Test", code: 1))
        }
        guard let article = ephemeralArticleToReturn else {
            throw DiscoveryError.contentFetchFailed(NSError(domain: "Test", code: 1))
        }
        await onArticleEntryFetched(article.url)
        return article
    }

    func clearCache() {
        clearCacheCallCount += 1
    }

    func prepareForFetch() -> DiscoverySource {
        prepareForFetchCallCount += 1
        return sourceToReturn
    }

    func reset() {
        executeCallCount = 0
        executeWithCallbackCallCount = 0
        clearCacheCallCount = 0
        prepareForFetchCallCount = 0
        shouldThrow = false
        ephemeralArticleToReturn = nil
        sourceToReturn = .kagiSmallWeb
        lastCallback = nil
    }
}
