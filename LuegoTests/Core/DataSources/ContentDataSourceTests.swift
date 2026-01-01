import Testing
import Foundation
@testable import Luego

@Suite("ContentDataSource Tests")
@MainActor
struct ContentDataSourceTests {
    var mockParserDataSource: MockLuegoParserDataSource
    var mockCache: MockParsedContentCacheDataSource
    var mockAPIDataSource: MockLuegoAPIDataSource
    var mockMetadataDataSource: MockMetadataDataSource
    var mockSDKManager: MockLuegoSDKManager
    var sut: ContentDataSource

    init() {
        mockParserDataSource = MockLuegoParserDataSource()
        mockCache = MockParsedContentCacheDataSource()
        mockAPIDataSource = MockLuegoAPIDataSource()
        mockMetadataDataSource = MockMetadataDataSource()
        mockSDKManager = MockLuegoSDKManager()
        sut = ContentDataSource(
            parserDataSource: mockParserDataSource,
            parsedContentCache: mockCache,
            luegoAPIDataSource: mockAPIDataSource,
            metadataDataSource: mockMetadataDataSource,
            sdkManager: mockSDKManager
        )
    }

    @Test("fetchContent returns cached content when available")
    func fetchContentReturnsCachedContent() async throws {
        let testURL = URL(string: "https://example.com/article")!
        let cachedContent = ArticleContent(
            title: "Cached Title",
            content: "Cached content"
        )
        mockCache.cachedContent[testURL] = cachedContent

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.title == "Cached Title")
        #expect(result.content == "Cached content")
        #expect(mockCache.getCallCount == 1)
        #expect(mockParserDataSource.parseCallCount == 0)
        #expect(mockAPIDataSource.fetchArticleCallCount == 0)
    }

    @Test("fetchContent uses SDK parser when ready and succeeds")
    func fetchContentUsesSDKParserWhenReady() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = true
        mockParserDataSource.resultToReturn = ParserResult(
            success: true,
            content: "# Parsed Content",
            metadata: ParserMetadata(
                title: "Parsed Title",
                author: "Author",
                publishedDate: nil,
                excerpt: "Excerpt",
                siteName: nil,
                thumbnail: nil
            ),
            error: nil
        )
        mockMetadataDataSource.htmlToReturn = "<html><body>Test</body></html>"

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.title == "Parsed Title")
        #expect(result.content == "# Parsed Content")
        #expect(mockParserDataSource.parseCallCount == 1)
        #expect(mockMetadataDataSource.fetchHTMLCallCount == 1)
        #expect(mockAPIDataSource.fetchArticleCallCount == 0)
        #expect(mockCache.saveCallCount == 1)
    }

    @Test("fetchContent falls back to API when SDK not ready")
    func fetchContentFallsBackToAPIWhenSDKNotReady() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = false
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# API Content",
            metadata: LuegoAPIMetadata(
                title: "API Title",
                author: "Test Author",
                publishedDate: "2024-12-28T10:30:00Z",
                estimatedReadTimeMinutes: 5,
                wordCount: 1000,
                sourceUrl: testURL.absoluteString,
                domain: "example.com",
                thumbnail: nil
            )
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.content == "# API Content")
        #expect(result.title == "API Title")
        #expect(mockParserDataSource.parseCallCount == 0)
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
        #expect(mockCache.saveCallCount == 1)
    }

    @Test("fetchContent falls back to API when SDK parsing fails")
    func fetchContentFallsBackToAPIWhenSDKFails() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = true
        mockParserDataSource.resultToReturn = ParserResult(
            success: false,
            content: nil,
            metadata: nil,
            error: "Parse error"
        )
        mockMetadataDataSource.htmlToReturn = "<html><body>Test</body></html>"
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# API Content",
            metadata: LuegoAPIMetadata(
                title: "API Title",
                author: nil,
                publishedDate: nil,
                estimatedReadTimeMinutes: nil,
                wordCount: nil,
                sourceUrl: testURL.absoluteString,
                domain: "example.com",
                thumbnail: nil
            )
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.content == "# API Content")
        #expect(mockParserDataSource.parseCallCount == 1)
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
    }

    @Test("fetchContent falls back to API when HTML fetch fails")
    func fetchContentFallsBackToAPIWhenHTMLFetchFails() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = true
        mockMetadataDataSource.shouldThrowOnFetchHTML = true
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# API Content",
            metadata: LuegoAPIMetadata(
                title: "API Title",
                author: nil,
                publishedDate: nil,
                estimatedReadTimeMinutes: nil,
                wordCount: nil,
                sourceUrl: testURL.absoluteString,
                domain: "example.com",
                thumbnail: nil
            )
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.content == "# API Content")
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
    }

    @Test("fetchContent throws when API fails")
    func fetchContentThrowsWhenAPIFails() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = false
        mockAPIDataSource.shouldThrowError = true
        mockAPIDataSource.errorToThrow = .serviceUnavailable

        await #expect(throws: LuegoAPIError.self) {
            try await sut.fetchContent(for: testURL, timeout: nil)
        }
    }

    @Test("validateURL delegates to MetadataDataSource")
    func validateURLDelegatesToMetadataDataSource() async throws {
        let testURL = URL(string: "https://example.com/article")!

        let result = try await sut.validateURL(testURL)

        #expect(mockMetadataDataSource.validateURLCallCount == 1)
        #expect(mockMetadataDataSource.lastValidatedURL == testURL)
    }

    @Test("fetchMetadata uses SDK parser when ready")
    func fetchMetadataUsesSDKParserWhenReady() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = true
        mockParserDataSource.resultToReturn = ParserResult(
            success: true,
            content: "# Content",
            metadata: ParserMetadata(
                title: "SDK Title",
                author: "Author",
                publishedDate: "2024-01-01T00:00:00Z",
                excerpt: "Excerpt",
                siteName: nil,
                thumbnail: "https://example.com/image.jpg"
            ),
            error: nil
        )
        mockMetadataDataSource.htmlToReturn = "<html><body>Test</body></html>"

        let result = try await sut.fetchMetadata(for: testURL, timeout: 30)

        #expect(result.title == "SDK Title")
        #expect(result.author == "Author")
        #expect(result.description == "Excerpt")
        #expect(mockMetadataDataSource.fetchHTMLCallCount == 1)
        #expect(mockParserDataSource.parseCallCount == 1)
        #expect(mockAPIDataSource.fetchArticleCallCount == 0)
    }

    @Test("fetchMetadata falls back to API when SDK not ready")
    func fetchMetadataFallsBackToAPIWhenSDKNotReady() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = false
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# Content",
            metadata: LuegoAPIMetadata(
                title: "API Title",
                author: "API Author",
                publishedDate: nil,
                estimatedReadTimeMinutes: nil,
                wordCount: 500,
                sourceUrl: testURL.absoluteString,
                domain: "example.com",
                thumbnail: nil
            )
        )

        let result = try await sut.fetchMetadata(for: testURL, timeout: 30)

        #expect(result.title == "API Title")
        #expect(result.author == "API Author")
        #expect(result.wordCount == 500)
        #expect(mockParserDataSource.parseCallCount == 0)
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
    }

    @Test("fetchMetadata falls back to API when SDK parsing fails")
    func fetchMetadataFallsBackToAPIWhenSDKFails() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockParserDataSource.mockIsReady = true
        mockParserDataSource.resultToReturn = ParserResult(
            success: false,
            content: nil,
            metadata: nil,
            error: "Parse error"
        )
        mockMetadataDataSource.htmlToReturn = "<html><body>Test</body></html>"
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# Content",
            metadata: LuegoAPIMetadata(
                title: "API Title",
                author: nil,
                publishedDate: nil,
                estimatedReadTimeMinutes: nil,
                wordCount: nil,
                sourceUrl: testURL.absoluteString,
                domain: "example.com",
                thumbnail: nil
            )
        )

        let result = try await sut.fetchMetadata(for: testURL, timeout: 30)

        #expect(result.title == "API Title")
        #expect(mockParserDataSource.parseCallCount == 1)
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
    }

    @Test("fetchHTML delegates to MetadataDataSource")
    func fetchHTMLDelegatesToMetadataDataSource() async throws {
        let testURL = URL(string: "https://example.com/article")!

        let result = try await sut.fetchHTML(from: testURL, timeout: 30)

        #expect(mockMetadataDataSource.fetchHTMLCallCount == 1)
        #expect(mockMetadataDataSource.lastFetchHTMLURL == testURL)
    }

    @Test("fetchContent uses fallback title from URL when API returns nil title")
    func fetchContentUsesFallbackTitleWhenNil() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# Content",
            metadata: LuegoAPIMetadata(
                title: nil,
                author: nil,
                publishedDate: nil,
                estimatedReadTimeMinutes: nil,
                wordCount: nil,
                sourceUrl: testURL.absoluteString,
                domain: "example.com",
                thumbnail: nil
            )
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.title == "example.com")
    }
}
