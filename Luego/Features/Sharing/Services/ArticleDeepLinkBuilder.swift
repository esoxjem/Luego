import Foundation

enum ArticleDeepLinkBuilder {
    static let scheme = "luegoreader"
    static let articleRoute = "article"
    static let articleURLQueryItemName = "url"

    static func makeArticleURL(for articleURL: URL) -> URL? {
        guard let scheme = articleURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.articleRoute
        components.queryItems = [
            URLQueryItem(name: Self.articleURLQueryItemName, value: articleURL.absoluteString)
        ]
        return components.url
    }
}
