import Testing
import Foundation
@testable import Luego

@Suite("MarkdownUtilities Tests")
struct MarkdownUtilitiesTests {
    @Test("stripFirstH1FromMarkdown removes matching H1")
    func stripMatchingH1() {
        let markdown = "# Test Title\n\nSome content here"

        let result = stripFirstH1FromMarkdown(markdown, matchingTitle: "Test Title")

        #expect(!result.contains("# Test Title"))
        #expect(result.contains("Some content here"))
    }

    @Test("stripFirstH1FromMarkdown preserves non-matching H1")
    func preservesNonMatchingH1() {
        let markdown = "# Different Title\n\nSome content"

        let result = stripFirstH1FromMarkdown(markdown, matchingTitle: "Test Title")

        #expect(result.contains("# Different Title"))
    }

    @Test("stripFirstH1FromMarkdown removes following empty lines")
    func removesFollowingEmptyLines() {
        let markdown = "# Test Title\n\n\n\nContent"

        let result = stripFirstH1FromMarkdown(markdown, matchingTitle: "Test Title")

        #expect(result == "Content")
    }

    @Test("stripFirstH1FromMarkdown handles similar titles")
    func handlesSimilarTitles() {
        let markdown = "# Test Article Title\n\nContent"

        let result = stripFirstH1FromMarkdown(markdown, matchingTitle: "Test Article Title!")

        #expect(!result.contains("# Test Article Title"))
    }

    @Test("stripFirstH1FromMarkdown returns unchanged when no H1")
    func returnsUnchangedWhenNoH1() {
        let markdown = "Some content without heading"

        let result = stripFirstH1FromMarkdown(markdown, matchingTitle: "Title")

        #expect(result == markdown)
    }

    @Test("stripFirstH1FromMarkdown only checks first 3 H1s")
    func onlyChecksFirstThreeH1s() {
        let markdown = "# First\n# Second\n# Third\n# Match Title\n\nContent"

        let result = stripFirstH1FromMarkdown(markdown, matchingTitle: "Match Title")

        #expect(result.contains("# Match Title"))
    }

    @Test("normalizeForComparison lowercases text")
    func normalizeLowercases() {
        let result = normalizeForComparison("HELLO World")

        #expect(result.contains("hello"))
        #expect(result.contains("world"))
    }

    @Test("normalizeForComparison removes punctuation")
    func normalizeRemovesPunctuation() {
        let result = normalizeForComparison("Hello, World!")

        #expect(!result.contains(","))
        #expect(!result.contains("!"))
    }

    @Test("normalizeForComparison normalizes whitespace")
    func normalizeNormalizesWhitespace() {
        let result = normalizeForComparison("hello   world")

        #expect(result == "hello world")
    }

    @Test("areSimilar returns true for identical texts")
    func areSimilarIdentical() {
        let result = areSimilar("hello world", "hello world")

        #expect(result == true)
    }

    @Test("areSimilar returns true for similar texts above threshold")
    func areSimilarAboveThreshold() {
        let result = areSimilar("a b c d e f g h", "a b c d e f g i")

        #expect(result == true)
    }

    @Test("areSimilar returns false for dissimilar texts")
    func areSimilarFalseForDissimilar() {
        let result = areSimilar("hello world", "goodbye universe completely different")

        #expect(result == false)
    }

    @Test("areSimilar returns true for identical empty strings")
    func areSimilarEmptyStrings() {
        let result = areSimilar("", "")

        #expect(result == true)
    }

    @Test("areSimilar returns false when one string is empty")
    func areSimilarOneEmpty() {
        let result = areSimilar("hello world", "")

        #expect(result == false)
    }

    @Test("findMatchingH1Index finds matching H1 at start")
    func findMatchingH1AtStart() {
        let lines = "# Test Title\nContent".split(separator: "\n", omittingEmptySubsequences: false)
        let normalizedTitle = normalizeForComparison("Test Title")

        let index = findMatchingH1Index(in: lines, normalizedTitle: normalizedTitle)

        #expect(index == 0)
    }

    @Test("findMatchingH1Index returns nil when no match")
    func findMatchingH1ReturnsNilNoMatch() {
        let lines = "# Other Title\nContent".split(separator: "\n", omittingEmptySubsequences: false)
        let normalizedTitle = normalizeForComparison("Test Title")

        let index = findMatchingH1Index(in: lines, normalizedTitle: normalizedTitle)

        #expect(index == nil)
    }

    @Test("findMatchingH1Index handles H1 with extra whitespace")
    func findMatchingH1WithWhitespace() {
        let lines = "#   Test Title  \nContent".split(separator: "\n", omittingEmptySubsequences: false)
        let normalizedTitle = normalizeForComparison("Test Title")

        let index = findMatchingH1Index(in: lines, normalizedTitle: normalizedTitle)

        #expect(index == 0)
    }
}
