import XCTest
import SwiftData
@testable import Luego

@MainActor
final class ArticleRepositoryTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var repository: ArticleRepository!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([Article.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        repository = ArticleRepository(modelContext: modelContext)
    }

    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testToggleFavoriteFromFalseToTrue() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isFavorite: false
        )
        modelContext.insert(article)
        try modelContext.save()

        XCTAssertFalse(article.isFavorite)

        try await repository.toggleFavorite(id: article.id)

        XCTAssertTrue(article.isFavorite)
    }

    func testToggleFavoriteFromTrueToFalse() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isFavorite: true
        )
        modelContext.insert(article)
        try modelContext.save()

        XCTAssertTrue(article.isFavorite)

        try await repository.toggleFavorite(id: article.id)

        XCTAssertFalse(article.isFavorite)
    }

    func testToggleFavoriteWithNonExistentIdDoesNotThrow() async throws {
        let nonExistentId = UUID()

        do {
            try await repository.toggleFavorite(id: nonExistentId)
        } catch {
            XCTFail("toggleFavorite should not throw for non-existent ID")
        }
    }

    func testToggleArchiveFromFalseToTrue() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isArchived: false
        )
        modelContext.insert(article)
        try modelContext.save()

        XCTAssertFalse(article.isArchived)

        try await repository.toggleArchive(id: article.id)

        XCTAssertTrue(article.isArchived)
    }

    func testToggleArchiveFromTrueToFalse() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isArchived: true
        )
        modelContext.insert(article)
        try modelContext.save()

        XCTAssertTrue(article.isArchived)

        try await repository.toggleArchive(id: article.id)

        XCTAssertFalse(article.isArchived)
    }

    func testToggleArchiveWithNonExistentIdDoesNotThrow() async throws {
        let nonExistentId = UUID()

        do {
            try await repository.toggleArchive(id: nonExistentId)
        } catch {
            XCTFail("toggleArchive should not throw for non-existent ID")
        }
    }

    func testToggleFavoritePersistsChange() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isFavorite: false
        )
        modelContext.insert(article)
        try modelContext.save()
        let articleId = article.id

        try await repository.toggleFavorite(id: articleId)

        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        let fetchedArticle = try modelContext.fetch(descriptor).first

        XCTAssertNotNil(fetchedArticle)
        XCTAssertTrue(fetchedArticle!.isFavorite)
    }

    func testToggleArchivePersistsChange() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isArchived: false
        )
        modelContext.insert(article)
        try modelContext.save()
        let articleId = article.id

        try await repository.toggleArchive(id: articleId)

        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        let fetchedArticle = try modelContext.fetch(descriptor).first

        XCTAssertNotNil(fetchedArticle)
        XCTAssertTrue(fetchedArticle!.isArchived)
    }

    func testMultipleTogglesWorkCorrectly() async throws {
        let article = Article(
            url: URL(string: "https://example.com/article")!,
            title: "Test Article",
            isFavorite: false,
            isArchived: false
        )
        modelContext.insert(article)
        try modelContext.save()

        try await repository.toggleFavorite(id: article.id)
        XCTAssertTrue(article.isFavorite)
        XCTAssertFalse(article.isArchived)

        try await repository.toggleArchive(id: article.id)
        XCTAssertTrue(article.isFavorite)
        XCTAssertTrue(article.isArchived)

        try await repository.toggleFavorite(id: article.id)
        XCTAssertFalse(article.isFavorite)
        XCTAssertTrue(article.isArchived)

        try await repository.toggleArchive(id: article.id)
        XCTAssertFalse(article.isFavorite)
        XCTAssertFalse(article.isArchived)
    }
}
