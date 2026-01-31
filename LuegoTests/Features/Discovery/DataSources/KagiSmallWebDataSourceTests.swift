import Testing
import Foundation
@testable import Luego

@Suite("KagiSmallWebDataSource Tests")
@MainActor
struct KagiSmallWebDataSourceTests {
    var opmlDataSource: OPMLDataSource
    var sut: KagiSmallWebDataSource

    private let testCacheKey = "smallweb_articles_v2"
    private let testCacheTimestampKey = "smallweb_cache_timestamp_v2"
    private let testSeenKey = "smallweb_shown_articles"

    init() {
        opmlDataSource = OPMLDataSource()
        sut = KagiSmallWebDataSource(opmlDataSource: opmlDataSource)
        clearTestData()
    }

    private func clearTestData() {
        UserDefaults.standard.removeObject(forKey: testCacheKey)
        UserDefaults.standard.removeObject(forKey: testCacheTimestampKey)
        UserDefaults.standard.removeObject(forKey: testSeenKey)
    }

    @Test("clearCache removes cached articles")
    func clearCacheRemovesCachedArticles() {
        clearTestData()
        let testArticles = [
            CachedArticleTestHelper(title: "Test", articleUrl: "https://example.com", htmlUrl: nil)
        ]
        if let data = try? JSONEncoder().encode(testArticles) {
            UserDefaults.standard.set(data, forKey: testCacheKey)
        }

        sut.clearCache()

        let cachedData = UserDefaults.standard.data(forKey: testCacheKey)
        #expect(cachedData == nil)
    }

    @Test("clearCache removes cache timestamp")
    func clearCacheRemovesCacheTimestamp() {
        clearTestData()
        UserDefaults.standard.set(Date(), forKey: testCacheTimestampKey)

        sut.clearCache()

        let timestamp = UserDefaults.standard.object(forKey: testCacheTimestampKey)
        #expect(timestamp == nil)
    }

    @Test("clearCache clears seen items tracker")
    func clearCacheClearsSeenTracker() {
        clearTestData()
        UserDefaults.standard.set(["https://example.com/1", "https://example.com/2"], forKey: testSeenKey)

        sut.clearCache()

        let seenItems = UserDefaults.standard.array(forKey: testSeenKey)
        #expect(seenItems == nil || (seenItems as? [String])?.isEmpty == true)
    }

    @Test("fetchArticles returns articles or throws on network failure")
    func fetchArticlesReturnsArticlesOrThrows() async {
        clearTestData()

        do {
            let articles = try await sut.fetchArticles(forceRefresh: true)
            #expect(articles.isEmpty == false)
        } catch {
            #expect(error is SmallWebError)
        }
    }

    @Test("randomArticleEntry returns entry or throws when no articles")
    func randomArticleEntryReturnsEntryOrThrows() async {
        clearTestData()

        do {
            let entry = try await sut.randomArticleEntry()
            #expect(entry.title.isEmpty == false)
        } catch {
            #expect(error is SmallWebError)
        }
    }
}

private struct CachedArticleTestHelper: Codable {
    let title: String
    let articleUrl: String
    let htmlUrl: String?
}

