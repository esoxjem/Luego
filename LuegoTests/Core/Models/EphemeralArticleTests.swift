import Testing
import Foundation
@testable import Luego

@Suite("EphemeralArticle Tests")
struct EphemeralArticleTests {
    @Test("domain returns host from URL")
    func domainReturnsHost() {
        let article = EphemeralArticleFixtures.createEphemeralArticle(
            url: URL(string: "https://blog.example.com/post")!
        )

        #expect(article.domain == "blog.example.com")
    }

    @Test("domain returns absoluteString when host unavailable")
    func domainReturnsAbsoluteStringWhenNoHost() {
        let article = EphemeralArticleFixtures.createEphemeralArticle(
            url: URL(string: "file:///local/file")!
        )

        #expect(article.domain == "file:///local/file")
    }

    @Test("estimatedReadingTime returns minimum 1 min for short content")
    func estimatedReadingTimeMinimum1Min() {
        let article = EphemeralArticleFixtures.createEphemeralArticle(content: "Short")

        #expect(article.estimatedReadingTime == "1 min read")
    }

    @Test("estimatedReadingTime calculates correctly for 200 words")
    func estimatedReadingTime200Words() {
        let words = (0..<200).map { _ in "word" }.joined(separator: " ")
        let article = EphemeralArticleFixtures.createEphemeralArticle(content: words)

        #expect(article.estimatedReadingTime == "1 min read")
    }

    @Test("estimatedReadingTime calculates correctly for 400 words")
    func estimatedReadingTime400Words() {
        let words = (0..<400).map { _ in "word" }.joined(separator: " ")
        let article = EphemeralArticleFixtures.createEphemeralArticle(content: words)

        #expect(article.estimatedReadingTime == "2 min read")
    }

    @Test("estimatedReadingTime formats with 'min read' suffix")
    func estimatedReadingTimeHasCorrectSuffix() {
        let article = EphemeralArticleFixtures.createEphemeralArticle()

        #expect(article.estimatedReadingTime.hasSuffix("min read"))
    }
}
