import Foundation

enum ArticleDeepLink {
    case article(URL)

    init(url: URL) throws {
        guard url.scheme?.lowercased() == "luegoreader" else {
            throw ArticleDeepLinkError.unsupportedLink
        }

        let route = ArticleDeepLink.routeComponent(from: url)

        guard route == "article" else {
            throw ArticleDeepLinkError.unsupportedLink
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let articleURLValue = components.queryItems?.first(where: { $0.name == "url" })?.value,
              !articleURLValue.isEmpty else {
            throw ArticleDeepLinkError.missingArticleURL
        }

        guard let articleURL = URL(string: articleURLValue) else {
            throw ArticleDeepLinkError.invalidArticleURL
        }

        guard let scheme = articleURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw ArticleDeepLinkError.unsupportedArticleURL
        }

        self = .article(articleURL)
    }

    private static func routeComponent(from url: URL) -> String {
        if let host = url.host()?.lowercased(), !host.isEmpty {
            return host
        }

        return url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }
}

enum ArticleDeepLinkError: LocalizedError {
    case unsupportedLink
    case missingArticleURL
    case invalidArticleURL
    case unsupportedArticleURL

    var errorDescription: String? {
        switch self {
        case .unsupportedLink:
            return "This link is not supported."
        case .missingArticleURL:
            return "This link is missing the article URL."
        case .invalidArticleURL:
            return "This article link is invalid."
        case .unsupportedArticleURL:
            return "Only web article URLs are supported."
        }
    }
}
