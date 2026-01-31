import Testing
import Foundation
@testable import Luego

@Suite("DiscoveryService Integration Tests")
@MainActor
struct DiscoveryServiceTests {
    var mockKagiDataSource: MockDiscoverySource
    var mockBlogrollDataSource: MockDiscoverySource
    var mockMetadataDataSource: MockMetadataDataSource
    var sut: DiscoveryService

    init() {
        mockKagiDataSource = MockDiscoverySource()
        mockBlogrollDataSource = MockDiscoverySource()
        mockMetadataDataSource = MockMetadataDataSource()
        sut = DiscoveryService(
            kagiSmallWebDataSource: mockKagiDataSource,
            blogrollDataSource: mockBlogrollDataSource,
            metadataDataSource: mockMetadataDataSource
        )
    }

    @Test("prepareForFetch returns same source for kagiSmallWeb")
    func prepareForFetchReturnsSameForKagi() {
        let result = sut.prepareForFetch(source: .kagiSmallWeb)

        #expect(result == .kagiSmallWeb)
    }

    @Test("prepareForFetch returns same source for blogroll")
    func prepareForFetchReturnsSameForBlogroll() {
        let result = sut.prepareForFetch(source: .blogroll)

        #expect(result == .blogroll)
    }

    @Test("prepareForFetch returns concrete source for surpriseMe")
    func prepareForFetchReturnsConcreteForSurpriseMe() {
        let result = sut.prepareForFetch(source: .surpriseMe)

        #expect(DiscoverySource.concreteSources.contains(result))
    }

    @Test("fetchRandomArticle returns EphemeralArticle from kagiSmallWeb")
    func fetchRandomArticleReturnsFromKagi() async throws {
        let testURL = URL(string: "https://example.com/kagi-article")!
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Kagi Article",
            articleUrl: testURL,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Kagi Article Title",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            description: "Description",
            content: "Article content",
            publishedDate: Date()
        )

        var callbackURL: URL?
        let article = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { url in
            callbackURL = url
        }

        #expect(article.url == testURL)
        #expect(article.title == "Kagi Article Title")
        #expect(article.content == "Article content")
        #expect(callbackURL == testURL)
    }

    @Test("fetchRandomArticle returns EphemeralArticle from blogroll")
    func fetchRandomArticleReturnsFromBlogroll() async throws {
        let testURL = URL(string: "https://example.com/blogroll-article")!
        mockBlogrollDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Blogroll Article",
            articleUrl: testURL,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Blogroll Article Title",
            thumbnailURL: nil,
            description: nil,
            content: "Blogroll content",
            publishedDate: nil
        )

        let article = try await sut.fetchRandomArticle(from: .blogroll) { _ in }

        #expect(article.url == testURL)
        #expect(article.title == "Blogroll Article Title")
    }

    @Test("fetchRandomArticle skips YouTube URLs and retries")
    func fetchRandomArticleSkipsYouTubeURLs() async throws {
        let youtubeURL = URL(string: "https://www.youtube.com/watch?v=123")!
        let validURL = URL(string: "https://example.com/valid")!

        mockKagiDataSource.articleEntriesToReturnSequentially = [
            SmallWebArticleEntry(title: "YouTube", articleUrl: youtubeURL, htmlUrl: nil),
            SmallWebArticleEntry(title: "Valid", articleUrl: validURL, htmlUrl: nil)
        ]
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Valid Article",
            thumbnailURL: nil,
            description: nil,
            content: "Valid content",
            publishedDate: nil
        )

        let article = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        #expect(mockKagiDataSource.randomArticleEntryCallCount == 2)
        #expect(article.url == validURL)
    }

    @Test("fetchRandomArticle skips youtu.be URLs")
    func fetchRandomArticleSkipsShortYouTubeURLs() async throws {
        let youtubeURL = URL(string: "https://youtu.be/123abc")!
        let validURL = URL(string: "https://example.com/valid")!

        mockKagiDataSource.articleEntriesToReturnSequentially = [
            SmallWebArticleEntry(title: "YouTube Short", articleUrl: youtubeURL, htmlUrl: nil),
            SmallWebArticleEntry(title: "Valid", articleUrl: validURL, htmlUrl: nil)
        ]
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Valid Article",
            thumbnailURL: nil,
            description: nil,
            content: "Valid content",
            publishedDate: nil
        )

        let article = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        #expect(mockKagiDataSource.randomArticleEntryCallCount == 2)
        #expect(article.url == validURL)
    }

    @Test("fetchRandomArticle retries up to 10 times for YouTube URLs")
    func fetchRandomArticleRetriesUpTo10Times() async throws {
        let youtubeURLs = (0..<10).map { index in
            SmallWebArticleEntry(
                title: "YouTube \(index)",
                articleUrl: URL(string: "https://youtube.com/video\(index)")!,
                htmlUrl: nil
            )
        }
        let validURL = URL(string: "https://example.com/valid")!

        mockKagiDataSource.articleEntriesToReturnSequentially = youtubeURLs + [
            SmallWebArticleEntry(title: "Valid", articleUrl: validURL, htmlUrl: nil)
        ]
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Valid",
            thumbnailURL: nil,
            description: nil,
            content: "Content",
            publishedDate: nil
        )

        let article = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        #expect(mockKagiDataSource.randomArticleEntryCallCount == 11)
        #expect(article.url == validURL)
    }

    @Test("fetchRandomArticle returns YouTube URL after 10 retries")
    func fetchRandomArticleReturnsYouTubeAfterMaxRetries() async throws {
        let youtubeURLs = (0..<15).map { index in
            SmallWebArticleEntry(
                title: "YouTube \(index)",
                articleUrl: URL(string: "https://youtube.com/video\(index)")!,
                htmlUrl: nil
            )
        }

        mockKagiDataSource.articleEntriesToReturnSequentially = youtubeURLs
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "YouTube Video",
            thumbnailURL: nil,
            description: nil,
            content: "Content",
            publishedDate: nil
        )

        let article = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        #expect(mockKagiDataSource.randomArticleEntryCallCount == 11)
        #expect(article.url.host()?.contains("youtube") == true)
    }

    @Test("fetchRandomArticle calls onArticleEntryFetched callback")
    func fetchRandomArticleCallsCallback() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Article",
            articleUrl: testURL,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            content: "Content",
            publishedDate: nil
        )

        var callbackInvoked = false
        var receivedURL: URL?
        _ = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { url in
            callbackInvoked = true
            receivedURL = url
        }

        #expect(callbackInvoked)
        #expect(receivedURL == testURL)
    }

    @Test("fetchRandomArticle fetches content via metadata data source")
    func fetchRandomArticleFetchesContent() async throws {
        let testURL = URL(string: "https://example.com/article")!
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Article",
            articleUrl: testURL,
            htmlUrl: nil
        )

        _ = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
        #expect(mockMetadataDataSource.lastFetchContentURL == testURL)
        #expect(mockMetadataDataSource.lastFetchContentTimeout == 10)
    }

    @Test("fetchRandomArticle throws DiscoveryError on content fetch failure")
    func fetchRandomArticleThrowsOnContentFailure() async throws {
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Article",
            articleUrl: URL(string: "https://example.com/article")!,
            htmlUrl: nil
        )
        mockMetadataDataSource.shouldThrowOnFetchContent = true

        await #expect(throws: DiscoveryError.self) {
            try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        }
    }

    @Test("fetchRandomArticle throws when data source fails")
    func fetchRandomArticleThrowsOnDataSourceFailure() async throws {
        mockKagiDataSource.shouldThrowOnRandomArticleEntry = true

        await #expect(throws: SmallWebError.self) {
            try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        }
    }

    @Test("fetchRandomArticle sets feedTitle from domain")
    func fetchRandomArticleSetsSourceFromDomain() async throws {
        let testURL = URL(string: "https://blog.example.com/article")!
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Article",
            articleUrl: testURL,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            content: "Content",
            publishedDate: nil
        )

        let article = try await sut.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        #expect(article.feedTitle == "blog.example.com")
    }

    @Test("clearCache for kagiSmallWeb clears only kagi data source")
    func clearCacheForKagiClearsOnlyKagi() {
        sut.clearCache(for: .kagiSmallWeb)

        #expect(mockKagiDataSource.clearCacheCallCount == 1)
        #expect(mockBlogrollDataSource.clearCacheCallCount == 0)
    }

    @Test("clearCache for blogroll clears only blogroll data source")
    func clearCacheForBlogrollClearsOnlyBlogroll() {
        sut.clearCache(for: .blogroll)

        #expect(mockKagiDataSource.clearCacheCallCount == 0)
        #expect(mockBlogrollDataSource.clearCacheCallCount == 1)
    }

    @Test("clearCache for surpriseMe clears all caches")
    func clearCacheForSurpriseMeClearsAll() {
        sut.clearCache(for: .surpriseMe)

        #expect(mockKagiDataSource.clearCacheCallCount == 1)
        #expect(mockBlogrollDataSource.clearCacheCallCount == 1)
    }

    @Test("clearAllCaches clears both data sources")
    func clearAllCachesClearsBoth() {
        sut.clearAllCaches()

        #expect(mockKagiDataSource.clearCacheCallCount == 1)
        #expect(mockBlogrollDataSource.clearCacheCallCount == 1)
    }

    @Test("fetchRandomArticle uses prepared source for surpriseMe")
    func fetchRandomArticleUsesPreparedSource() async throws {
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Kagi",
            articleUrl: URL(string: "https://kagi.example.com")!,
            htmlUrl: nil
        )
        mockBlogrollDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Blogroll",
            articleUrl: URL(string: "https://blogroll.example.com")!,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            content: "Content",
            publishedDate: nil
        )

        let preparedSource = sut.prepareForFetch(source: .surpriseMe)
        _ = try await sut.fetchRandomArticle(from: .surpriseMe) { _ in }

        if preparedSource == .kagiSmallWeb {
            #expect(mockKagiDataSource.randomArticleEntryCallCount == 1)
            #expect(mockBlogrollDataSource.randomArticleEntryCallCount == 0)
        } else {
            #expect(mockKagiDataSource.randomArticleEntryCallCount == 0)
            #expect(mockBlogrollDataSource.randomArticleEntryCallCount == 1)
        }
    }
}
