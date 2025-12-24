import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("ReaderService Integration Tests")
@MainActor
struct ReaderServiceTests {
    var modelContainer: ModelContainer
    var modelContext: ModelContext
    var mockMetadataDataSource: MockMetadataDataSource
    var sut: ReaderService

    init() throws {
        modelContainer = try createTestModelContainer()
        modelContext = modelContainer.mainContext
        mockMetadataDataSource = MockMetadataDataSource()
        sut = ReaderService(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource
        )
    }

    private func createAndPersistArticle(
        url: URL = URL(string: "https://example.com/article")!,
        title: String = "Test Article",
        content: String? = nil,
        readPosition: Double = 0.0
    ) throws -> Article {
        let article = Article(
            id: UUID(),
            url: url,
            title: title,
            content: content,
            savedDate: Date(),
            thumbnailURL: nil,
            publishedDate: nil,
            readPosition: readPosition
        )
        modelContext.insert(article)
        try modelContext.save()
        return article
    }

    private func fetchArticleById(_ id: UUID) throws -> Article? {
        let descriptor = FetchDescriptor<Article>()
        let articles = try modelContext.fetch(descriptor)
        return articles.first { $0.id == id }
    }

    @Test("fetchContent fetches and persists content when article has no content")
    func fetchContentFetchesWhenNoContent() async throws {
        let article = try createAndPersistArticle(content: nil)
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Fetched Title",
            thumbnailURL: nil,
            description: nil,
            content: "Fetched content from the web",
            publishedDate: nil
        )

        let updatedArticle = try await sut.fetchContent(for: article, forceRefresh: false)

        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
        #expect(mockMetadataDataSource.lastFetchContentURL == article.url)
        #expect(updatedArticle.content == "Fetched content from the web")
    }

    @Test("fetchContent returns immediately when article has content and forceRefresh is false")
    func fetchContentReturnsImmediatelyWhenHasContent() async throws {
        let article = try createAndPersistArticle(content: "Existing content")

        let returnedArticle = try await sut.fetchContent(for: article, forceRefresh: false)

        #expect(mockMetadataDataSource.fetchContentCallCount == 0)
        #expect(returnedArticle.content == "Existing content")
    }

    @Test("fetchContent refetches when forceRefresh is true even with existing content")
    func fetchContentRefetchesOnForceRefresh() async throws {
        let article = try createAndPersistArticle(content: "Old content")
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "New Title",
            thumbnailURL: nil,
            description: nil,
            content: "New content from refresh",
            publishedDate: nil
        )

        let updatedArticle = try await sut.fetchContent(for: article, forceRefresh: true)

        #expect(mockMetadataDataSource.fetchContentCallCount == 1)
        #expect(updatedArticle.content == "New content from refresh")
    }

    @Test("fetchContent persists content to SwiftData")
    func fetchContentPersistsToSwiftData() async throws {
        let article = try createAndPersistArticle(content: nil)
        mockMetadataDataSource.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            content: "Persisted content",
            publishedDate: nil
        )

        _ = try await sut.fetchContent(for: article, forceRefresh: false)

        let fetchedArticle = try fetchArticleById(article.id)
        #expect(fetchedArticle?.content == "Persisted content")
    }

    @Test("fetchContent throws when metadata data source fails")
    func fetchContentThrowsOnDataSourceFailure() async throws {
        let article = try createAndPersistArticle(content: nil)
        mockMetadataDataSource.shouldThrowOnFetchContent = true

        await #expect(throws: ArticleMetadataError.self) {
            try await sut.fetchContent(for: article, forceRefresh: false)
        }
    }

    @Test("updateReadPosition updates position for existing article")
    func updateReadPositionUpdatesExistingArticle() async throws {
        let article = try createAndPersistArticle(readPosition: 0.0)

        try await sut.updateReadPosition(articleId: article.id, position: 0.75)

        let fetchedArticle = try fetchArticleById(article.id)
        #expect(fetchedArticle?.readPosition == 0.75)
    }

    @Test("updateReadPosition silently succeeds for non-existent article")
    func updateReadPositionSilentlySucceedsForNonExistent() async throws {
        let nonExistentId = UUID()

        try await sut.updateReadPosition(articleId: nonExistentId, position: 0.5)
    }

    @Test("updateReadPosition persists changes to SwiftData")
    func updateReadPositionPersistsChanges() async throws {
        let article = try createAndPersistArticle(readPosition: 0.25)

        try await sut.updateReadPosition(articleId: article.id, position: 0.9)

        let fetchedArticle = try fetchArticleById(article.id)
        #expect(fetchedArticle?.readPosition == 0.9)
    }

    @Test("updateReadPosition can update position multiple times")
    func updateReadPositionCanUpdateMultipleTimes() async throws {
        let article = try createAndPersistArticle(readPosition: 0.0)

        try await sut.updateReadPosition(articleId: article.id, position: 0.25)
        try await sut.updateReadPosition(articleId: article.id, position: 0.5)
        try await sut.updateReadPosition(articleId: article.id, position: 0.75)

        let fetchedArticle = try fetchArticleById(article.id)
        #expect(fetchedArticle?.readPosition == 0.75)
    }

    @Test("updateReadPosition accepts boundary values")
    func updateReadPositionAcceptsBoundaryValues() async throws {
        let article = try createAndPersistArticle(readPosition: 0.5)

        try await sut.updateReadPosition(articleId: article.id, position: 0.0)

        var fetchedArticle = try fetchArticleById(article.id)
        #expect(fetchedArticle?.readPosition == 0.0)

        try await sut.updateReadPosition(articleId: article.id, position: 1.0)

        fetchedArticle = try fetchArticleById(article.id)
        #expect(fetchedArticle?.readPosition == 1.0)
    }
}
