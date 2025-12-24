import Foundation
@testable import Luego

@MainActor
final class MockDiscoveryService: DiscoveryServiceProtocol {
    var fetchRandomArticleCallCount = 0
    var prepareForFetchCallCount = 0
    var clearCacheCallCount = 0
    var clearAllCachesCallCount = 0

    var lastFetchedSource: DiscoverySource?
    var lastPreparedSource: DiscoverySource?
    var lastClearedSource: DiscoverySource?

    var ephemeralArticleToReturn: EphemeralArticle?
    var sourceToReturnForPrepare: DiscoverySource?
    var shouldThrowOnFetchRandomArticle = false

    enum MockError: Error {
        case mockError
    }

    func fetchRandomArticle(
        from source: DiscoverySource,
        onArticleEntryFetched: @escaping @MainActor (URL) -> Void
    ) async throws -> EphemeralArticle {
        fetchRandomArticleCallCount += 1
        lastFetchedSource = source
        if shouldThrowOnFetchRandomArticle {
            throw MockError.mockError
        }
        return ephemeralArticleToReturn ?? EphemeralArticleFixtures.createEphemeralArticle()
    }

    func prepareForFetch(source: DiscoverySource) -> DiscoverySource {
        prepareForFetchCallCount += 1
        lastPreparedSource = source
        return sourceToReturnForPrepare ?? source
    }

    func clearCache(for source: DiscoverySource) {
        clearCacheCallCount += 1
        lastClearedSource = source
    }

    func clearAllCaches() {
        clearAllCachesCallCount += 1
    }
}
