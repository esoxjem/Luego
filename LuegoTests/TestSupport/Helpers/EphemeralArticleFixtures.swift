import Foundation
@testable import Luego

enum EphemeralArticleFixtures {
    static func createEphemeralArticle(
        url: URL = URL(string: "https://example.com/discovery")!,
        title: String = "Discovered Article",
        content: String = "This is the content of the discovered article with enough words to test reading time calculation accurately.",
        thumbnailURL: URL? = nil,
        publishedDate: Date? = nil,
        feedTitle: String = "Example Feed"
    ) -> EphemeralArticle {
        EphemeralArticle(
            url: url,
            title: title,
            content: content,
            thumbnailURL: thumbnailURL,
            publishedDate: publishedDate,
            feedTitle: feedTitle
        )
    }

    static func createEphemeralArticleWithContent(wordCount: Int = 400) -> EphemeralArticle {
        let words = (0..<wordCount).map { _ in "word" }.joined(separator: " ")
        return createEphemeralArticle(content: words)
    }
}
