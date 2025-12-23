import Foundation
@testable import Luego

@MainActor
final class MockDiscoverySourceRepository: DiscoverySourceProtocol {
    var sourceIdentifier: DiscoverySource

    var articlesToReturn: [SmallWebArticleEntry] = []
    var randomArticleToReturn: SmallWebArticleEntry?

    var fetchArticlesCallCount = 0
    var randomArticleEntryCallCount = 0
    var clearCacheCallCount = 0

    var shouldThrowOnFetch = false
    var shouldThrowOnRandom = false

    var lastForceRefresh: Bool?

    init(source: DiscoverySource = .kagiSmallWeb) {
        self.sourceIdentifier = source
    }

    func fetchArticles(forceRefresh: Bool) async throws -> [SmallWebArticleEntry] {
        fetchArticlesCallCount += 1
        lastForceRefresh = forceRefresh
        if shouldThrowOnFetch {
            throw SmallWebError.fetchFailed(NSError(domain: "Test", code: 1))
        }
        return articlesToReturn
    }

    func randomArticleEntry() async throws -> SmallWebArticleEntry {
        randomArticleEntryCallCount += 1
        if shouldThrowOnRandom {
            throw SmallWebError.noArticlesAvailable
        }
        guard let article = randomArticleToReturn else {
            throw SmallWebError.noArticlesAvailable
        }
        return article
    }

    func clearCache() {
        clearCacheCallCount += 1
    }

    func reset() {
        articlesToReturn = []
        randomArticleToReturn = nil
        fetchArticlesCallCount = 0
        randomArticleEntryCallCount = 0
        clearCacheCallCount = 0
        shouldThrowOnFetch = false
        shouldThrowOnRandom = false
        lastForceRefresh = nil
    }
}
