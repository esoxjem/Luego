import Testing
import Foundation
@testable import Luego

@Suite("Article Tests")
struct ArticleTests {
    @Test("domain returns host from URL")
    func domainReturnsHost() {
        let article = ArticleFixtures.createArticle(
            url: URL(string: "https://blog.example.com/article")!
        )

        #expect(article.domain == "blog.example.com")
    }

    @Test("domain returns absoluteString when host unavailable")
    func domainReturnsAbsoluteStringWhenNoHost() {
        let article = ArticleFixtures.createArticle(
            url: URL(string: "file:///path/to/file")!
        )

        #expect(article.domain == "file:///path/to/file")
    }

    @Test("estimatedReadingTime returns 0 min for nil content")
    func estimatedReadingTimeNilContent() {
        let article = ArticleFixtures.createArticle(content: nil)

        #expect(article.estimatedReadingTime == "0 min")
    }

    @Test("estimatedReadingTime returns 0 min for empty content")
    func estimatedReadingTimeEmptyContent() {
        let article = ArticleFixtures.createArticle(content: "")

        #expect(article.estimatedReadingTime == "0 min")
    }

    @Test("estimatedReadingTime returns minimum 1 min for short content")
    func estimatedReadingTimeMinimum1Min() {
        let article = ArticleFixtures.createArticle(content: "Short content")

        #expect(article.estimatedReadingTime == "1 min")
    }

    @Test("estimatedReadingTime calculates correctly for 200 words")
    func estimatedReadingTime200Words() {
        let words = (0..<200).map { _ in "word" }.joined(separator: " ")
        let article = ArticleFixtures.createArticle(content: words)

        #expect(article.estimatedReadingTime == "1 min")
    }

    @Test("estimatedReadingTime calculates correctly for 400 words")
    func estimatedReadingTime400Words() {
        let words = (0..<400).map { _ in "word" }.joined(separator: " ")
        let article = ArticleFixtures.createArticle(content: words)

        #expect(article.estimatedReadingTime == "2 min")
    }

    @Test("estimatedReadingTime rounds up")
    func estimatedReadingTimeRoundsUp() {
        let words = (0..<250).map { _ in "word" }.joined(separator: " ")
        let article = ArticleFixtures.createArticle(content: words)

        #expect(article.estimatedReadingTime == "2 min")
    }

    @Test("estimatedReadingTime ignores whitespace-only words")
    func estimatedReadingTimeIgnoresWhitespace() {
        let content = "word1   word2\n\nword3\t\tword4"
        let article = ArticleFixtures.createArticle(content: content)

        #expect(article.estimatedReadingTime == "1 min")
    }

    @Test("equatable compares by id only")
    func equatableById() {
        let id = UUID()
        let article1 = ArticleFixtures.createArticle(
            id: id,
            url: URL(string: "https://example1.com")!,
            title: "Title 1"
        )
        let article2 = ArticleFixtures.createArticle(
            id: id,
            url: URL(string: "https://example2.com")!,
            title: "Title 2"
        )

        #expect(article1 == article2)
    }

    @Test("equatable returns false for different ids")
    func equatableDifferentIds() {
        let article1 = ArticleFixtures.createArticle(id: UUID())
        let article2 = ArticleFixtures.createArticle(id: UUID())

        #expect(article1 != article2)
    }
}
