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

@Suite("Article Excerpt Tests")
struct ArticleExcerptTests {
    @Test("excerpt returns empty string for nil content")
    func excerptNilContent() {
        let article = ArticleFixtures.createArticle(content: nil)

        #expect(article.excerpt == "")
    }

    @Test("excerpt returns empty string for empty content")
    func excerptEmptyContent() {
        let article = ArticleFixtures.createArticle(content: "")

        #expect(article.excerpt == "")
    }

    @Test("excerpt returns short content without truncation")
    func excerptShortContent() {
        let article = ArticleFixtures.createArticle(content: "Short paragraph text.")

        #expect(article.excerpt == "Short paragraph text.")
    }

    @Test("excerpt truncates at word boundary with ellipsis")
    func excerptTruncatesAtWordBoundary() {
        let longContent = "This is a sentence that goes on and on and contains many words that will exceed the one hundred and twenty character limit for excerpts in article rows."
        let article = ArticleFixtures.createArticle(content: longContent)

        #expect(article.excerpt.hasSuffix("…"))
        #expect(article.excerpt.count <= 125) // 120 + ellipsis + possible word
        #expect(!article.excerpt.contains("  ")) // No double spaces
    }

    @Test("excerpt strips markdown headers")
    func excerptStripsMarkdownHeaders() {
        let content = "# This is a header\n\nThis is the actual content."
        let article = ArticleFixtures.createArticle(content: content)

        #expect(!article.excerpt.contains("#"))
        #expect(article.excerpt.contains("actual content"))
    }

    @Test("excerpt strips markdown links keeping text")
    func excerptStripsMarkdownLinks() {
        let content = "Check out this [amazing link](https://example.com) for more info."
        let article = ArticleFixtures.createArticle(content: content)

        #expect(!article.excerpt.contains("["))
        #expect(!article.excerpt.contains("]("))
        #expect(article.excerpt.contains("amazing link"))
    }

    @Test("excerpt strips markdown bold and italic")
    func excerptStripsMarkdownBoldItalic() {
        let content = "This has **bold** and *italic* and __underline__ text."
        let article = ArticleFixtures.createArticle(content: content)

        #expect(!article.excerpt.contains("**"))
        #expect(!article.excerpt.contains("__"))
        #expect(article.excerpt.contains("bold"))
        #expect(article.excerpt.contains("italic"))
    }

    @Test("excerpt strips markdown images")
    func excerptStripsMarkdownImages() {
        let content = "Here is an image: ![alt text](https://example.com/img.png) and more text."
        let article = ArticleFixtures.createArticle(content: content)

        #expect(!article.excerpt.contains("!["))
        #expect(!article.excerpt.contains("img.png"))
        #expect(article.excerpt.contains("and more text"))
    }

    @Test("excerpt collapses multiple newlines into spaces")
    func excerptCollapsesNewlines() {
        let content = "First paragraph.\n\n\nSecond paragraph.\n\nThird."
        let article = ArticleFixtures.createArticle(content: content)

        #expect(!article.excerpt.contains("\n"))
        #expect(article.excerpt.contains("First paragraph. Second paragraph. Third."))
    }
}

@Suite("String Markdown Stripping Tests")
struct StringMarkdownStrippingTests {
    @Test("strippingMarkdown removes code blocks")
    func stripsCodeBlocks() {
        let markdown = "Before code\n```swift\nlet x = 1\n```\nAfter code"
        let result = markdown.strippingMarkdown()

        #expect(!result.contains("```"))
        #expect(!result.contains("let x = 1"))
    }

    @Test("strippingMarkdown preserves inline code text")
    func preservesInlineCodeText() {
        let markdown = "Use `print()` to output"
        let result = markdown.strippingMarkdown()

        #expect(!result.contains("`"))
        #expect(result.contains("print()"))
    }

    @Test("strippingMarkdown removes blockquotes marker")
    func removesBlockquotes() {
        let markdown = "> This is a quote"
        let result = markdown.strippingMarkdown()

        #expect(!result.hasPrefix(">"))
    }

    @Test("strippingMarkdown removes list markers")
    func removesListMarkers() {
        let markdown = "- Item one\n* Item two\n+ Item three"
        let result = markdown.strippingMarkdown()

        #expect(!result.contains("- Item"))
        #expect(!result.contains("* Item"))
        #expect(!result.contains("+ Item"))
    }

    @Test("strippingMarkdown removes numbered list markers")
    func removesNumberedListMarkers() {
        let markdown = "1. First\n2. Second"
        let result = markdown.strippingMarkdown()

        #expect(!result.contains("1. "))
        #expect(!result.contains("2. "))
    }
}
