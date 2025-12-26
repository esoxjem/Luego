import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("Discovery to ReadingList Integration Tests")
@MainActor
struct DiscoveryToReadingListIntegrationTests {
    var modelContainer: ModelContainer
    var modelContext: ModelContext
    var mockKagiDataSource: MockDiscoverySource
    var mockBlogrollDataSource: MockDiscoverySource
    var mockMetadataDataSource: MockMetadataDataSource
    var discoveryService: DiscoveryService
    var articleService: ArticleService

    init() throws {
        modelContainer = try createTestModelContainer()
        modelContext = modelContainer.mainContext
        mockKagiDataSource = MockDiscoverySource(sourceIdentifier: .kagiSmallWeb)
        mockBlogrollDataSource = MockDiscoverySource(sourceIdentifier: .blogroll)
        mockMetadataDataSource = MockMetadataDataSource()

        discoveryService = DiscoveryService(
            kagiSmallWebDataSource: mockKagiDataSource,
            blogrollDataSource: mockBlogrollDataSource,
            metadataDataSource: mockMetadataDataSource
        )

        articleService = ArticleService(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource
        )
    }

    private func fetchAllArticles() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    @Test("discovered article can be saved to reading list")
    func discoveredArticleCanBeSaved() async throws {
        let discoveryURL = URL(string: "https://discovery.example.com/article")!
        let thumbnailURL = URL(string: "https://discovery.example.com/thumb.jpg")!
        let publishedDate = Date()

        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Discovery Entry",
            articleUrl: discoveryURL,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Discovered Article Title",
            thumbnailURL: thumbnailURL,
            faviconURL: nil,
            description: "Description",
            content: "Full article content from discovery",
            publishedDate: publishedDate
        )

        let ephemeralArticle = try await discoveryService.fetchRandomArticle(from: .kagiSmallWeb) { _ in }

        let savedArticle = try await articleService.saveEphemeralArticle(ephemeralArticle)

        #expect(savedArticle.url == discoveryURL)
        #expect(savedArticle.title == "Discovered Article Title")
        #expect(savedArticle.content == "Full article content from discovery")
        #expect(savedArticle.thumbnailURL == thumbnailURL)

        let articles = try fetchAllArticles()
        #expect(articles.count == 1)
        #expect(articles.first?.id == savedArticle.id)
    }

    @Test("multiple discovered articles can be saved independently")
    func multipleDiscoveredArticlesCanBeSaved() async throws {
        let url1 = URL(string: "https://example.com/article1")!
        let url2 = URL(string: "https://example.com/article2")!

        mockKagiDataSource.articleEntriesToReturnSequentially = [
            SmallWebArticleEntry(title: "Entry 1", articleUrl: url1, htmlUrl: nil),
            SmallWebArticleEntry(title: "Entry 2", articleUrl: url2, htmlUrl: nil)
        ]

        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Article 1",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            content: "Content 1",
            publishedDate: nil
        )
        let ephemeral1 = try await discoveryService.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        _ = try await articleService.saveEphemeralArticle(ephemeral1)

        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Article 2",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            content: "Content 2",
            publishedDate: nil
        )
        let ephemeral2 = try await discoveryService.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        _ = try await articleService.saveEphemeralArticle(ephemeral2)

        let articles = try fetchAllArticles()
        #expect(articles.count == 2)
    }

    @Test("saved article preserves all ephemeral article data")
    func savedArticlePreservesAllData() async throws {
        let url = URL(string: "https://example.com/complete-article")!
        let thumbnail = URL(string: "https://example.com/image.jpg")!
        let pubDate = Date().addingTimeInterval(-86400)

        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Entry",
            articleUrl: url,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Complete Title",
            thumbnailURL: thumbnail,
            faviconURL: nil,
            description: "Complete description",
            content: "Complete content body",
            publishedDate: pubDate
        )

        let ephemeral = try await discoveryService.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        let saved = try await articleService.saveEphemeralArticle(ephemeral)

        #expect(saved.url == ephemeral.url)
        #expect(saved.title == ephemeral.title)
        #expect(saved.content == ephemeral.content)
        #expect(saved.thumbnailURL == ephemeral.thumbnailURL)
        #expect(saved.publishedDate == ephemeral.publishedDate)
    }

    @Test("saved article has default values for new properties")
    func savedArticleHasDefaults() async throws {
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Entry",
            articleUrl: URL(string: "https://example.com/article")!,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            content: "Content",
            publishedDate: nil
        )

        let ephemeral = try await discoveryService.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        let saved = try await articleService.saveEphemeralArticle(ephemeral)

        #expect(saved.isFavorite == false)
        #expect(saved.isArchived == false)
        #expect(saved.readPosition == 0.0)
    }

    @Test("discovered article content is immediately available after save")
    func contentAvailableImmediately() async throws {
        mockKagiDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Entry",
            articleUrl: URL(string: "https://example.com/article")!,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            content: "Pre-fetched content from discovery",
            publishedDate: nil
        )

        let ephemeral = try await discoveryService.fetchRandomArticle(from: .kagiSmallWeb) { _ in }
        let saved = try await articleService.saveEphemeralArticle(ephemeral)

        #expect(saved.content != nil)
        #expect(saved.content == "Pre-fetched content from discovery")
    }

    @Test("discovery from blogroll source saves correctly")
    func blogrollDiscoverySavesCorrectly() async throws {
        let blogrollURL = URL(string: "https://blogroll.example.com/post")!

        mockBlogrollDataSource.articleEntryToReturn = SmallWebArticleEntry(
            title: "Blogroll Post",
            articleUrl: blogrollURL,
            htmlUrl: nil
        )
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Blogroll Article",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            content: "Content from blogroll source",
            publishedDate: nil
        )

        let ephemeral = try await discoveryService.fetchRandomArticle(from: .blogroll) { _ in }
        let saved = try await articleService.saveEphemeralArticle(ephemeral)

        #expect(saved.url == blogrollURL)
        #expect(saved.title == "Blogroll Article")
    }
}

@Suite("Share Extension to ReadingList Integration Tests")
@MainActor
struct ShareExtensionToReadingListIntegrationTests {
    var modelContainer: ModelContainer
    var modelContext: ModelContext
    var mockMetadataDataSource: MockMetadataDataSource
    var mockUserDefaultsDataSource: MockUserDefaultsDataSource
    var sharingService: SharingService
    var articleService: ArticleService

    init() throws {
        modelContainer = try createTestModelContainer()
        modelContext = modelContainer.mainContext
        mockMetadataDataSource = MockMetadataDataSource()
        mockUserDefaultsDataSource = MockUserDefaultsDataSource()

        sharingService = SharingService(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource,
            userDefaultsDataSource: mockUserDefaultsDataSource
        )

        articleService = ArticleService(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource
        )
    }

    private func fetchAllArticles() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    @Test("shared URLs sync to reading list")
    func sharedURLsSyncToReadingList() async throws {
        let sharedURL = URL(string: "https://shared.example.com/article")!
        mockUserDefaultsDataSource.sharedURLs = [sharedURL]
        mockMetadataDataSource.metadataToReturn = ArticleMetadata(
            title: "Shared Article",
            thumbnailURL: nil,
            faviconURL: nil,
            description: "Shared description",
            publishedDate: nil
        )

        let syncedArticles = try await sharingService.syncSharedArticles()

        #expect(syncedArticles.count == 1)
        #expect(syncedArticles.first?.url == sharedURL)
        #expect(syncedArticles.first?.title == "Shared Article")

        let allArticles = try fetchAllArticles()
        #expect(allArticles.count == 1)
    }

    @Test("synced articles can be favorited after save")
    func syncedArticlesCanBeFavorited() async throws {
        let sharedURL = URL(string: "https://shared.example.com/article")!
        mockUserDefaultsDataSource.sharedURLs = [sharedURL]

        let syncedArticles = try await sharingService.syncSharedArticles()
        let articleId = syncedArticles.first!.id

        try await articleService.toggleFavorite(id: articleId)

        let articles = try fetchAllArticles()
        #expect(articles.first?.isFavorite == true)
    }

    @Test("synced articles can be archived after save")
    func syncedArticlesCanBeArchived() async throws {
        let sharedURL = URL(string: "https://shared.example.com/article")!
        mockUserDefaultsDataSource.sharedURLs = [sharedURL]

        let syncedArticles = try await sharingService.syncSharedArticles()
        let articleId = syncedArticles.first!.id

        try await articleService.toggleArchive(id: articleId)

        let articles = try fetchAllArticles()
        #expect(articles.first?.isArchived == true)
    }

    @Test("synced articles can be deleted")
    func syncedArticlesCanBeDeleted() async throws {
        let sharedURL = URL(string: "https://shared.example.com/article")!
        mockUserDefaultsDataSource.sharedURLs = [sharedURL]

        let syncedArticles = try await sharingService.syncSharedArticles()
        let articleId = syncedArticles.first!.id

        try await articleService.deleteArticle(id: articleId)

        let articles = try fetchAllArticles()
        #expect(articles.isEmpty)
    }

    @Test("multiple shared URLs create separate articles")
    func multipleSharedURLsCreateSeparateArticles() async throws {
        mockUserDefaultsDataSource.sharedURLs = [
            URL(string: "https://example.com/article1")!,
            URL(string: "https://example.com/article2")!,
            URL(string: "https://example.com/article3")!
        ]

        let syncedArticles = try await sharingService.syncSharedArticles()

        #expect(syncedArticles.count == 3)

        let allArticles = try fetchAllArticles()
        #expect(allArticles.count == 3)

        let urls = Set(allArticles.map { $0.url.absoluteString })
        #expect(urls.contains("https://example.com/article1"))
        #expect(urls.contains("https://example.com/article2"))
        #expect(urls.contains("https://example.com/article3"))
    }
}
