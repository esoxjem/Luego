import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("ArticleService Integration Tests")
@MainActor
struct ArticleServiceTests {
    var modelContainer: ModelContainer
    var modelContext: ModelContext
    var mockMetadataDataSource: MockMetadataDataSource
    var sut: ArticleService

    init() throws {
        modelContainer = try createTestModelContainer()
        modelContext = modelContainer.mainContext
        mockMetadataDataSource = MockMetadataDataSource()
        sut = ArticleService(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource
        )
    }

    @Test("addArticle validates URL via metadata data source")
    func addArticleValidatesURL() async throws {
        let url = URL(string: "https://example.com/article")!

        _ = try await sut.addArticle(url: url)

        #expect(mockMetadataDataSource.validateURLCallCount == 1)
        #expect(mockMetadataDataSource.lastValidatedURL == url)
    }

    @Test("addArticle fetches metadata for validated URL")
    func addArticleFetchesMetadata() async throws {
        let url = URL(string: "https://example.com/article")!

        _ = try await sut.addArticle(url: url)

        #expect(mockMetadataDataSource.fetchMetadataCallCount == 1)
        #expect(mockMetadataDataSource.lastFetchMetadataURL == url)
    }

    @Test("addArticle creates article with fetched metadata")
    func addArticleCreatesWithMetadata() async throws {
        let url = URL(string: "https://example.com/article")!
        let publishedDate = Date()
        let thumbnailURL = URL(string: "https://example.com/image.jpg")!
        mockMetadataDataSource.metadataToReturn = ArticleMetadata(
            title: "Custom Title",
            thumbnailURL: thumbnailURL,
            faviconURL: nil,
            description: "Custom description",
            publishedDate: publishedDate
        )

        let article = try await sut.addArticle(url: url)

        #expect(article.title == "Custom Title")
        #expect(article.url == url)
        #expect(article.thumbnailURL == thumbnailURL)
        #expect(article.publishedDate == publishedDate)
        #expect(article.content == nil)
        #expect(article.readPosition == 0)
    }

    @Test("addArticle persists article to SwiftData")
    func addArticlePersistsToSwiftData() async throws {
        let url = URL(string: "https://example.com/article")!

        let article = try await sut.addArticle(url: url)

        let fetchedArticles = try await sut.getAllArticles()
        #expect(fetchedArticles.count == 1)
        #expect(fetchedArticles.first?.id == article.id)
    }

    @Test("addArticle throws when URL validation fails")
    func addArticleThrowsOnInvalidURL() async throws {
        let url = URL(string: "https://example.com/article")!
        mockMetadataDataSource.shouldThrowOnValidateURL = true

        await #expect(throws: ArticleMetadataError.self) {
            try await sut.addArticle(url: url)
        }
    }

    @Test("addArticle throws when metadata fetch fails")
    func addArticleThrowsOnMetadataFetchFailure() async throws {
        let url = URL(string: "https://example.com/article")!
        mockMetadataDataSource.shouldThrowOnFetchMetadata = true

        await #expect(throws: ArticleMetadataError.self) {
            try await sut.addArticle(url: url)
        }
    }

    @Test("getAllArticles returns empty array when no articles")
    func getAllArticlesReturnsEmptyWhenNone() async throws {
        let articles = try await sut.getAllArticles()

        #expect(articles.isEmpty)
    }

    @Test("getAllArticles returns articles sorted by savedDate descending")
    func getAllArticlesReturnsSortedByDate() async throws {
        let olderDate = Date().addingTimeInterval(-86400)
        let newerDate = Date()

        mockMetadataDataSource.metadataToReturn = ArticleMetadata(
            title: "Older Article",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            publishedDate: nil
        )
        let olderArticle = try await sut.addArticle(url: URL(string: "https://example.com/older")!)

        olderArticle.savedDate = olderDate
        try modelContext.save()

        mockMetadataDataSource.metadataToReturn = ArticleMetadata(
            title: "Newer Article",
            thumbnailURL: nil,
            faviconURL: nil,
            description: nil,
            publishedDate: nil
        )
        let newerArticle = try await sut.addArticle(url: URL(string: "https://example.com/newer")!)

        newerArticle.savedDate = newerDate
        try modelContext.save()

        let articles = try await sut.getAllArticles()

        #expect(articles.count == 2)
        #expect(articles[0].title == "Newer Article")
        #expect(articles[1].title == "Older Article")
    }

    @Test("deleteArticle removes article from SwiftData")
    func deleteArticleRemovesFromSwiftData() async throws {
        let url = URL(string: "https://example.com/article")!
        let article = try await sut.addArticle(url: url)
        let articleId = article.id

        try await sut.deleteArticle(id: articleId)

        let articles = try await sut.getAllArticles()
        #expect(articles.isEmpty)
    }

    @Test("deleteArticle does nothing for non-existent id")
    func deleteArticleNoOpForNonExistentId() async throws {
        let url = URL(string: "https://example.com/article")!
        _ = try await sut.addArticle(url: url)
        let nonExistentId = UUID()

        try await sut.deleteArticle(id: nonExistentId)

        let articles = try await sut.getAllArticles()
        #expect(articles.count == 1)
    }

    @Test("updateArticle persists changes to SwiftData")
    func updateArticlePersistsChanges() async throws {
        let url = URL(string: "https://example.com/article")!
        let article = try await sut.addArticle(url: url)

        article.title = "Updated Title"
        article.content = "New content"
        try await sut.updateArticle(article)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.title == "Updated Title")
        #expect(articles.first?.content == "New content")
    }

    @Test("toggleFavorite flips isFavorite from false to true")
    func toggleFavoriteFlipsToTrue() async throws {
        let url = URL(string: "https://example.com/article")!
        let article = try await sut.addArticle(url: url)
        #expect(article.isFavorite == false)

        try await sut.toggleFavorite(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isFavorite == true)
    }

    @Test("toggleFavorite flips isFavorite from true to false")
    func toggleFavoriteFlipsToFalse() async throws {
        let url = URL(string: "https://example.com/article")!
        let article = try await sut.addArticle(url: url)
        article.isFavorite = true
        try modelContext.save()

        try await sut.toggleFavorite(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isFavorite == false)
    }

    @Test("toggleFavorite does nothing for non-existent id")
    func toggleFavoriteNoOpForNonExistentId() async throws {
        let nonExistentId = UUID()

        try await sut.toggleFavorite(id: nonExistentId)
    }

    @Test("toggleArchive flips isArchived from false to true")
    func toggleArchiveFlipsToTrue() async throws {
        let url = URL(string: "https://example.com/article")!
        let article = try await sut.addArticle(url: url)
        #expect(article.isArchived == false)

        try await sut.toggleArchive(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isArchived == true)
    }

    @Test("toggleArchive flips isArchived from true to false")
    func toggleArchiveFlipsToFalse() async throws {
        let url = URL(string: "https://example.com/article")!
        let article = try await sut.addArticle(url: url)
        article.isArchived = true
        try modelContext.save()

        try await sut.toggleArchive(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isArchived == false)
    }

    @Test("toggleArchive does nothing for non-existent id")
    func toggleArchiveNoOpForNonExistentId() async throws {
        let nonExistentId = UUID()

        try await sut.toggleArchive(id: nonExistentId)
    }

    @Test("favoriting archived article clears archive flag")
    func favoritingArchivedArticleClearsArchive() async throws {
        let article = try await sut.addArticle(url: URL(string: "https://example.com/article")!)
        article.isArchived = true
        try modelContext.save()

        try await sut.toggleFavorite(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isFavorite == true)
        #expect(articles.first?.isArchived == false)
    }

    @Test("archiving favorited article clears favorite flag")
    func archivingFavoritedArticleClearsFavorite() async throws {
        let article = try await sut.addArticle(url: URL(string: "https://example.com/article")!)
        article.isFavorite = true
        try modelContext.save()

        try await sut.toggleArchive(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isArchived == true)
        #expect(articles.first?.isFavorite == false)
    }

    @Test("unfavoriting article does not affect archive status")
    func unfavoritingArticlePreservesArchiveStatus() async throws {
        let article = try await sut.addArticle(url: URL(string: "https://example.com/article")!)
        article.isFavorite = true
        article.isArchived = false
        try modelContext.save()

        try await sut.toggleFavorite(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isFavorite == false)
        #expect(articles.first?.isArchived == false)
    }

    @Test("unarchiving article does not affect favorite status")
    func unarchivingArticlePreservesFavoriteStatus() async throws {
        let article = try await sut.addArticle(url: URL(string: "https://example.com/article")!)
        article.isArchived = true
        article.isFavorite = false
        try modelContext.save()

        try await sut.toggleArchive(id: article.id)

        let articles = try await sut.getAllArticles()
        #expect(articles.first?.isArchived == false)
        #expect(articles.first?.isFavorite == false)
    }

    @Test("saveEphemeralArticle converts and persists to SwiftData")
    func saveEphemeralArticleConvertsAndPersists() async throws {
        let ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle(
            url: URL(string: "https://example.com/discovered")!,
            title: "Discovered Title",
            content: "Discovered content",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            publishedDate: Date(),
            feedTitle: "Test Feed"
        )

        let savedArticle = try await sut.saveEphemeralArticle(ephemeralArticle)

        #expect(savedArticle.url == ephemeralArticle.url)
        #expect(savedArticle.title == ephemeralArticle.title)
        #expect(savedArticle.content == ephemeralArticle.content)
        #expect(savedArticle.thumbnailURL == ephemeralArticle.thumbnailURL)
        #expect(savedArticle.publishedDate == ephemeralArticle.publishedDate)

        let articles = try await sut.getAllArticles()
        #expect(articles.count == 1)
        #expect(articles.first?.id == savedArticle.id)
    }

    @Test("saveEphemeralArticle does not call metadata data source")
    func saveEphemeralArticleSkipsMetadataFetch() async throws {
        let ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle()

        _ = try await sut.saveEphemeralArticle(ephemeralArticle)

        #expect(mockMetadataDataSource.validateURLCallCount == 0)
        #expect(mockMetadataDataSource.fetchMetadataCallCount == 0)
    }

    @Test("multiple articles can be added and retrieved")
    func multipleArticlesCanBeAddedAndRetrieved() async throws {
        let urls = [
            URL(string: "https://example.com/article1")!,
            URL(string: "https://example.com/article2")!,
            URL(string: "https://example.com/article3")!
        ]

        for (index, url) in urls.enumerated() {
            mockMetadataDataSource.metadataToReturn = ArticleMetadata(
                title: "Article \(index + 1)",
                thumbnailURL: nil,
                faviconURL: nil,
                description: nil,
                publishedDate: nil
            )
            _ = try await sut.addArticle(url: url)
        }

        let articles = try await sut.getAllArticles()
        #expect(articles.count == 3)
    }
}
