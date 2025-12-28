import Testing
import Foundation
@testable import Luego

@Suite("ContentDataSource Tests")
@MainActor
struct ContentDataSourceTests {
    var mockAPIDataSource: MockLuegoAPIDataSource
    var mockMetadataDataSource: MockMetadataDataSource
    var sut: ContentDataSource

    init() {
        mockAPIDataSource = MockLuegoAPIDataSource()
        mockMetadataDataSource = MockMetadataDataSource()
        sut = ContentDataSource(
            luegoAPIDataSource: mockAPIDataSource,
            metadataDataSource: mockMetadataDataSource
        )
    }

    @Test("fetchContent returns API response when successful")
    func fetchContentReturnsAPIResponseWhenSuccessful() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockAPIDataSource.responseToReturn = LuegoAPIResponse(
            content: "# Test Content",
            metadata: LuegoAPIMetadata(
                title: "API Title",
                author: "Test Author",
                publishedDate: "2024-12-28T10:30:00Z",
                estimatedReadTimeMinutes: 5,
                wordCount: 1000,
                sourceUrl: testURL.absoluteString,
                domain: "example.com"
            )
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.content == "# Test Content")
        #expect(result.title == "API Title")
        #expect(result.author == "Test Author")
        #expect(result.wordCount == 1000)
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
        #expect(mockMetadataDataSource.fetchContentCallCount == 0)
    }

    @Test("fetchContent falls back to local parsing when API fails")
    func fetchContentFallsBackWhenAPIFails() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockAPIDataSource.shouldThrowError = true
        mockAPIDataSource.errorToThrow = .serviceUnavailable

        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Local Title",
            thumbnailURL: nil,
            description: nil,
            content: "Local content from MetadataDataSource",
            publishedDate: Date()
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.content == "Local content from MetadataDataSource")
        #expect(result.title == "Local Title")
        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
    }

    @Test("fetchContent falls back when API returns network error")
    func fetchContentFallsBackOnNetworkError() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockAPIDataSource.shouldThrowError = true
        mockAPIDataSource.errorToThrow = .networkError(URLError(.notConnectedToInternet))

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
    }

    @Test("fetchContent falls back when API returns unauthorized")
    func fetchContentFallsBackOnUnauthorized() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockAPIDataSource.shouldThrowError = true
        mockAPIDataSource.errorToThrow = .unauthorized

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
    }

    @Test("fetchContent throws when both API and local fail")
    func fetchContentThrowsWhenBothFail() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockAPIDataSource.shouldThrowError = true
        mockMetadataDataSource.shouldThrowOnFetchContent = true

        await #expect(throws: ArticleMetadataError.self) {
            try await sut.fetchContent(for: testURL, timeout: nil)
        }

        #expect(mockAPIDataSource.fetchArticleCallCount == 1)
        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
    }

    @Test("validateURL delegates to MetadataDataSource")
    func validateURLDelegatesToMetadataDataSource() async throws {
        let testURL = URL(string: "https://example.com/article")!

        let result = try await sut.validateURL(testURL)

        #expect(mockMetadataDataSource.validateURLCallCount == 1)
        #expect(mockMetadataDataSource.lastValidatedURL == testURL)
    }

    @Test("fetchMetadata delegates to MetadataDataSource")
    func fetchMetadataDelegatesToMetadataDataSource() async throws {
        let testURL = URL(string: "https://example.com/article")!

        let result = try await sut.fetchMetadata(for: testURL, timeout: 30)

        #expect(mockMetadataDataSource.fetchMetadataCallCount == 1)
        #expect(mockMetadataDataSource.lastFetchMetadataURL == testURL)
        #expect(mockAPIDataSource.fetchArticleCallCount == 0)
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
                domain: "example.com"
            )
        )

        let result = try await sut.fetchContent(for: testURL, timeout: nil)

        #expect(result.title == "example.com")
    }
}
