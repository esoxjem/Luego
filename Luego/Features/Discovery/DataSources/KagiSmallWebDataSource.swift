import Foundation

@MainActor
protocol DiscoverySourceProtocol: Sendable {
    var sourceIdentifier: DiscoverySource { get }
    func fetchArticles(forceRefresh: Bool) async throws -> [SmallWebArticleEntry]
    func randomArticleEntry() async throws -> SmallWebArticleEntry
    func clearCache()
}

typealias SmallWebDataSourceProtocol = DiscoverySourceProtocol

enum SmallWebError: LocalizedError {
    case fetchFailed(Error)
    case parsingFailed
    case noArticlesAvailable

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Could not load the article list"
        case .parsingFailed:
            return "Could not parse the article list"
        case .noArticlesAvailable:
            return "No articles available"
        }
    }
}

@MainActor
final class KagiSmallWebDataSource: DiscoverySourceProtocol {
    let sourceIdentifier: DiscoverySource = .kagiSmallWeb

    private let opmlDataSource: OPMLDataSource
    private let seenTracker: SeenItemTracker
    private let opmlURL = URL(string: "https://kagi.com/smallweb/opml")!
    private let cacheKey = "smallweb_articles_v2"
    private let cacheTimestampKey = "smallweb_cache_timestamp_v2"
    private let cacheDuration: TimeInterval = 24 * 60 * 60

    private var cachedArticles: [SmallWebArticleEntry] = []

    init(opmlDataSource: OPMLDataSource) {
        self.opmlDataSource = opmlDataSource
        self.seenTracker = SeenItemTracker(storageKey: "smallweb_shown_articles")
        loadCachedArticles()
    }

    func fetchArticles(forceRefresh: Bool = false) async throws -> [SmallWebArticleEntry] {
        if !forceRefresh && !cachedArticles.isEmpty && isCacheValid() {
            return cachedArticles
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: opmlURL)
            let articles = opmlDataSource.parse(data)

            guard !articles.isEmpty else {
                throw SmallWebError.parsingFailed
            }

            cachedArticles = articles
            saveArticlesToCache(articles)
            return articles
        } catch let error as SmallWebError {
            throw error
        } catch {
            throw SmallWebError.fetchFailed(error)
        }
    }

    func randomArticleEntry() async throws -> SmallWebArticleEntry {
        let articles = try await fetchArticles(forceRefresh: false)

        guard !articles.isEmpty else {
            throw SmallWebError.noArticlesAvailable
        }

        let unseenArticles = seenTracker.filterUnseen(articles) { $0.articleUrl.absoluteString }
        let didReset = seenTracker.resetIfNeeded(totalCount: articles.count, unseenCount: unseenArticles.count)

        let articlesToChooseFrom = didReset ? articles : (unseenArticles.isEmpty ? articles : unseenArticles)

        guard let selectedArticle = articlesToChooseFrom.randomElement() else {
            throw SmallWebError.noArticlesAvailable
        }

        seenTracker.markAsSeen(selectedArticle.articleUrl.absoluteString)
        return selectedArticle
    }

    private func isCacheValid() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return false
        }
        return Date().timeIntervalSince(timestamp) < cacheDuration
    }

    private func loadCachedArticles() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CachedArticle].self, from: data) else {
            return
        }

        cachedArticles = cached.compactMap { cachedArticle -> SmallWebArticleEntry? in
            guard let url = URL(string: cachedArticle.articleUrl) else { return nil }
            let htmlUrl = cachedArticle.htmlUrl.flatMap { URL(string: $0) }
            return SmallWebArticleEntry(title: cachedArticle.title, articleUrl: url, htmlUrl: htmlUrl)
        }
    }

    private func saveArticlesToCache(_ articles: [SmallWebArticleEntry]) {
        let cached = articles.map { article in
            CachedArticle(
                title: article.title,
                articleUrl: article.articleUrl.absoluteString,
                htmlUrl: article.htmlUrl?.absoluteString
            )
        }
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        }
    }

    func clearCache() {
        cachedArticles = []
        seenTracker.clear()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
}

private struct CachedArticle: Codable {
    let title: String
    let articleUrl: String
    let htmlUrl: String?
}
