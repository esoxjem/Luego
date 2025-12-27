import Foundation
@testable import Luego

enum ArticleFixtures {
    static func createArticle(
        id: UUID = UUID(),
        url: URL = URL(string: "https://example.com/article")!,
        title: String = "Test Article",
        content: String? = nil,
        savedDate: Date = Date(),
        thumbnailURL: URL? = nil,
        publishedDate: Date? = nil,
        readPosition: Double = 0.0,
        isFavorite: Bool = false,
        isArchived: Bool = false
    ) -> Article {
        Article(
            id: id,
            url: url,
            title: title,
            content: content,
            savedDate: savedDate,
            thumbnailURL: thumbnailURL,
            publishedDate: publishedDate,
            readPosition: readPosition,
            isFavorite: isFavorite,
            isArchived: isArchived
        )
    }

    static func createMultipleArticles(count: Int) -> [Article] {
        (0..<count).map { index in
            createArticle(
                url: URL(string: "https://example.com/article\(index)")!,
                title: "Test Article \(index)",
                savedDate: Date().addingTimeInterval(Double(-index * 3600))
            )
        }
    }

    static func createArticleWithContent(wordCount: Int = 400) -> Article {
        let words = (0..<wordCount).map { _ in "word" }.joined(separator: " ")
        return createArticle(content: words)
    }
}
