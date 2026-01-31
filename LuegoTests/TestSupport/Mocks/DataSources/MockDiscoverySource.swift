import Foundation
@testable import Luego

@MainActor
final class MockDiscoverySource: DiscoverySourceProtocol {
    var fetchArticlesCallCount = 0
    var randomArticleEntryCallCount = 0
    var clearCacheCallCount = 0

    var lastFetchArticlesForceRefresh: Bool?

    var shouldThrowOnFetchArticles = false
    var shouldThrowOnRandomArticleEntry = false

    var articlesToReturn: [SmallWebArticleEntry] = []
    var articleEntryToReturn: SmallWebArticleEntry?
    var articleEntriesToReturnSequentially: [SmallWebArticleEntry] = []
    private var sequentialIndex = 0

    var fetchArticlesError: Error = SmallWebError.noArticlesAvailable
    var randomArticleEntryError: Error = SmallWebError.noArticlesAvailable

    init() {}

    func fetchArticles(forceRefresh: Bool) async throws -> [SmallWebArticleEntry] {
        fetchArticlesCallCount += 1
        lastFetchArticlesForceRefresh = forceRefresh
        if shouldThrowOnFetchArticles {
            throw fetchArticlesError
        }
        return articlesToReturn
    }

    func randomArticleEntry() async throws -> SmallWebArticleEntry {
        randomArticleEntryCallCount += 1
        if shouldThrowOnRandomArticleEntry {
            throw randomArticleEntryError
        }

        if !articleEntriesToReturnSequentially.isEmpty {
            let entry = articleEntriesToReturnSequentially[sequentialIndex % articleEntriesToReturnSequentially.count]
            sequentialIndex += 1
            return entry
        }

        return articleEntryToReturn ?? SmallWebArticleEntry(
            title: "Mock Article",
            articleUrl: URL(string: "https://example.com/mock-article")!,
            htmlUrl: nil
        )
    }

    func clearCache() {
        clearCacheCallCount += 1
    }

    func reset() {
        fetchArticlesCallCount = 0
        randomArticleEntryCallCount = 0
        clearCacheCallCount = 0
        lastFetchArticlesForceRefresh = nil
        shouldThrowOnFetchArticles = false
        shouldThrowOnRandomArticleEntry = false
        articlesToReturn = []
        articleEntryToReturn = nil
        articleEntriesToReturnSequentially = []
        sequentialIndex = 0
    }
}
