import Foundation

protocol SmallWebRepositoryProtocol: Sendable {
    func fetchArticles(forceRefresh: Bool) async throws -> [SmallWebArticleEntry]
    func randomArticleEntry() async throws -> SmallWebArticleEntry
    func clearCache()
}

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
final class SmallWebRepository: SmallWebRepositoryProtocol {
    private let opmlDataSource: OPMLDataSource
    private let opmlURL = URL(string: "https://kagi.com/smallweb/opml")!
    private let cacheKey = "smallweb_articles_v2"
    private let cacheTimestampKey = "smallweb_cache_timestamp_v2"
    private let cacheDuration: TimeInterval = 24 * 60 * 60
    private let shownArticlesKey = "smallweb_shown_articles"
    private let resetThreshold = 0.8

    private var cachedArticles: [SmallWebArticleEntry] = []
    private var shownArticleURLs: Set<String> = []

    init(opmlDataSource: OPMLDataSource) {
        self.opmlDataSource = opmlDataSource
        loadCachedArticles()
        loadShownArticles()
    }

    func fetchArticles(forceRefresh: Bool = false) async throws -> [SmallWebArticleEntry] {
        if !forceRefresh && !cachedArticles.isEmpty && isCacheValid() {
            return cachedArticles
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: opmlURL)
            #if DEBUG
            print("[Discovery] Downloaded OPML: \(data.count) bytes (\(data.count / 1024)KB)")
            #endif
            let articles = opmlDataSource.parse(data)
            #if DEBUG
            print("[Discovery] Parsed \(articles.count) articles from OPML")
            #endif

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

        let unseenArticles = filterUnseenArticles(from: articles)
        let unseenCountBeforeReset = unseenArticles.count

        #if DEBUG
        print("[Discovery] Total articles: \(articles.count), Shown: \(shownArticleURLs.count), Unseen: \(unseenCountBeforeReset)")
        #endif

        resetShownArticlesIfNeeded(totalCount: articles.count, unseenCount: unseenArticles.count)

        let didReset = shownArticleURLs.isEmpty && unseenCountBeforeReset < articles.count
        #if DEBUG
        if didReset {
            print("[Discovery] Reset shown articles - starting fresh cycle")
        }
        #endif

        let articlesToChooseFrom = didReset ? articles : (unseenArticles.isEmpty ? articles : unseenArticles)

        guard let selectedArticle = articlesToChooseFrom.randomElement() else {
            throw SmallWebError.noArticlesAvailable
        }

        #if DEBUG
        print("[Discovery] Selected: \(selectedArticle.title) - \(selectedArticle.articleUrl.absoluteString)")
        #endif

        markArticleAsShown(selectedArticle)
        return selectedArticle
    }

    private func filterUnseenArticles(from articles: [SmallWebArticleEntry]) -> [SmallWebArticleEntry] {
        articles.filter { !shownArticleURLs.contains($0.articleUrl.absoluteString) }
    }

    private func resetShownArticlesIfNeeded(totalCount: Int, unseenCount: Int) {
        let shownRatio = Double(totalCount - unseenCount) / Double(totalCount)
        guard shownRatio >= resetThreshold || unseenCount == 0 else { return }
        shownArticleURLs.removeAll()
        saveShownArticles()
    }

    private func markArticleAsShown(_ article: SmallWebArticleEntry) {
        shownArticleURLs.insert(article.articleUrl.absoluteString)
        saveShownArticles()
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

    private func loadShownArticles() {
        guard let data = UserDefaults.standard.data(forKey: shownArticlesKey),
              let urls = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return
        }
        shownArticleURLs = urls
    }

    private func saveShownArticles() {
        guard let data = try? JSONEncoder().encode(shownArticleURLs) else { return }
        UserDefaults.standard.set(data, forKey: shownArticlesKey)
    }

    func clearCache() {
        cachedArticles = []
        shownArticleURLs.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        UserDefaults.standard.removeObject(forKey: shownArticlesKey)
        #if DEBUG
        print("[Discovery] Cache cleared")
        #endif
    }
}

private struct CachedArticle: Codable {
    let title: String
    let articleUrl: String
    let htmlUrl: String?
}
