import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("ArticleRepository Tests")
@MainActor
struct ArticleRepositoryTests {
    var modelContainer: ModelContainer
    var modelContext: ModelContext
    var repository: ArticleRepository

    init() throws {
        modelContainer = try createTestModelContainer()
        modelContext = modelContainer.mainContext
        repository = ArticleRepository(modelContext: modelContext)
    }

    @Test("getAll returns empty array when no articles exist")
    func getAllReturnsEmptyWhenNoArticles() async throws {
        let articles = try await repository.getAll()
        #expect(articles.isEmpty)
    }

    @Test("getAll returns articles sorted by savedDate descending")
    func getAllReturnsSortedArticles() async throws {
        let older = ArticleFixtures.createArticle(
            url: URL(string: "https://example.com/older")!,
            savedDate: Date().addingTimeInterval(-3600)
        )
        let newer = ArticleFixtures.createArticle(
            url: URL(string: "https://example.com/newer")!,
            savedDate: Date()
        )
        modelContext.insert(older)
        modelContext.insert(newer)
        try modelContext.save()

        let articles = try await repository.getAll()

        #expect(articles.count == 2)
        #expect(articles[0].savedDate > articles[1].savedDate)
    }

    @Test("save inserts article and returns it")
    func saveInsertsArticle() async throws {
        let article = ArticleFixtures.createArticle()

        let savedArticle = try await repository.save(article)

        #expect(savedArticle.id == article.id)
        let fetched = try await repository.getAll()
        #expect(fetched.count == 1)
        #expect(fetched[0].id == article.id)
    }

    @Test("save persists article properties correctly")
    func savePersistsProperties() async throws {
        let article = ArticleFixtures.createArticle(
            title: "Test Title",
            content: "Test Content",
            isFavorite: true,
            isArchived: false
        )

        let saved = try await repository.save(article)

        #expect(saved.title == "Test Title")
        #expect(saved.content == "Test Content")
        #expect(saved.isFavorite == true)
        #expect(saved.isArchived == false)
    }

    @Test("delete removes article by id")
    func deleteRemovesArticle() async throws {
        let article = ArticleFixtures.createArticle()
        modelContext.insert(article)
        try modelContext.save()

        try await repository.delete(id: article.id)

        let articles = try await repository.getAll()
        #expect(articles.isEmpty)
    }

    @Test("delete with non-existent id does not throw")
    func deleteNonExistentDoesNotThrow() async throws {
        try await repository.delete(id: UUID())
    }

    @Test("delete only removes specified article")
    func deleteOnlyRemovesSpecified() async throws {
        let article1 = ArticleFixtures.createArticle(url: URL(string: "https://example.com/1")!)
        let article2 = ArticleFixtures.createArticle(url: URL(string: "https://example.com/2")!)
        modelContext.insert(article1)
        modelContext.insert(article2)
        try modelContext.save()

        try await repository.delete(id: article1.id)

        let articles = try await repository.getAll()
        #expect(articles.count == 1)
        #expect(articles[0].id == article2.id)
    }

    @Test("update persists changes")
    func updatePersistsChanges() async throws {
        let article = ArticleFixtures.createArticle(title: "Original")
        modelContext.insert(article)
        try modelContext.save()

        article.title = "Updated"
        try await repository.update(article)

        let articles = try await repository.getAll()
        #expect(articles[0].title == "Updated")
    }

    @Test("updateReadPosition updates position correctly")
    func updateReadPositionWorks() async throws {
        let article = ArticleFixtures.createArticle(readPosition: 0.0)
        modelContext.insert(article)
        try modelContext.save()

        try await repository.updateReadPosition(articleId: article.id, position: 0.75)

        #expect(article.readPosition == 0.75)
    }

    @Test("updateReadPosition with non-existent id does not throw")
    func updateReadPositionNonExistentDoesNotThrow() async throws {
        try await repository.updateReadPosition(articleId: UUID(), position: 0.5)
    }

    @Test("toggleFavorite changes false to true")
    func toggleFavoriteFalseToTrue() async throws {
        let article = ArticleFixtures.createArticle(isFavorite: false)
        modelContext.insert(article)
        try modelContext.save()

        #expect(article.isFavorite == false)

        try await repository.toggleFavorite(id: article.id)

        #expect(article.isFavorite == true)
    }

    @Test("toggleFavorite changes true to false")
    func toggleFavoriteTrueToFalse() async throws {
        let article = ArticleFixtures.createArticle(isFavorite: true)
        modelContext.insert(article)
        try modelContext.save()

        #expect(article.isFavorite == true)

        try await repository.toggleFavorite(id: article.id)

        #expect(article.isFavorite == false)
    }

    @Test("toggleFavorite with non-existent id does not throw")
    func toggleFavoriteNonExistentDoesNotThrow() async throws {
        try await repository.toggleFavorite(id: UUID())
    }

    @Test("toggleFavorite persists change")
    func toggleFavoritePersistsChange() async throws {
        let article = ArticleFixtures.createArticle(isFavorite: false)
        modelContext.insert(article)
        try modelContext.save()
        let articleId = article.id

        try await repository.toggleFavorite(id: articleId)

        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        let fetchedArticle = try modelContext.fetch(descriptor).first

        #expect(fetchedArticle != nil)
        #expect(fetchedArticle!.isFavorite == true)
    }

    @Test("toggleArchive changes false to true")
    func toggleArchiveFalseToTrue() async throws {
        let article = ArticleFixtures.createArticle(isArchived: false)
        modelContext.insert(article)
        try modelContext.save()

        #expect(article.isArchived == false)

        try await repository.toggleArchive(id: article.id)

        #expect(article.isArchived == true)
    }

    @Test("toggleArchive changes true to false")
    func toggleArchiveTrueToFalse() async throws {
        let article = ArticleFixtures.createArticle(isArchived: true)
        modelContext.insert(article)
        try modelContext.save()

        #expect(article.isArchived == true)

        try await repository.toggleArchive(id: article.id)

        #expect(article.isArchived == false)
    }

    @Test("toggleArchive with non-existent id does not throw")
    func toggleArchiveNonExistentDoesNotThrow() async throws {
        try await repository.toggleArchive(id: UUID())
    }

    @Test("toggleArchive persists change")
    func toggleArchivePersistsChange() async throws {
        let article = ArticleFixtures.createArticle(isArchived: false)
        modelContext.insert(article)
        try modelContext.save()
        let articleId = article.id

        try await repository.toggleArchive(id: articleId)

        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        let fetchedArticle = try modelContext.fetch(descriptor).first

        #expect(fetchedArticle != nil)
        #expect(fetchedArticle!.isArchived == true)
    }

    @Test("multiple toggles work correctly")
    func multipleTogglesWorkCorrectly() async throws {
        let article = ArticleFixtures.createArticle(isFavorite: false, isArchived: false)
        modelContext.insert(article)
        try modelContext.save()

        try await repository.toggleFavorite(id: article.id)
        #expect(article.isFavorite == true)
        #expect(article.isArchived == false)

        try await repository.toggleArchive(id: article.id)
        #expect(article.isFavorite == true)
        #expect(article.isArchived == true)

        try await repository.toggleFavorite(id: article.id)
        #expect(article.isFavorite == false)
        #expect(article.isArchived == true)

        try await repository.toggleArchive(id: article.id)
        #expect(article.isFavorite == false)
        #expect(article.isArchived == false)
    }
}
