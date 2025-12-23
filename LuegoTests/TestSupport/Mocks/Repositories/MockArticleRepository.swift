import Foundation
@testable import Luego

@MainActor
final class MockArticleRepository: ArticleRepositoryProtocol {
    var articles: [Article] = []

    var getAllCallCount = 0
    var saveCallCount = 0
    var deleteCallCount = 0
    var updateCallCount = 0
    var updateReadPositionCallCount = 0
    var toggleFavoriteCallCount = 0
    var toggleArchiveCallCount = 0

    var shouldThrowOnGetAll = false
    var shouldThrowOnSave = false
    var shouldThrowOnDelete = false
    var shouldThrowOnUpdate = false
    var shouldThrowOnUpdateReadPosition = false
    var shouldThrowOnToggleFavorite = false
    var shouldThrowOnToggleArchive = false

    var lastSavedArticle: Article?
    var lastDeletedId: UUID?
    var lastUpdatedArticle: Article?
    var lastToggledFavoriteId: UUID?
    var lastToggledArchiveId: UUID?
    var lastReadPositionUpdate: (articleId: UUID, position: Double)?

    func getAll() async throws -> [Article] {
        getAllCallCount += 1
        if shouldThrowOnGetAll {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        return articles
    }

    func save(_ article: Article) async throws -> Article {
        saveCallCount += 1
        if shouldThrowOnSave {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        lastSavedArticle = article
        articles.append(article)
        return article
    }

    func delete(id: UUID) async throws {
        deleteCallCount += 1
        lastDeletedId = id
        if shouldThrowOnDelete {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        articles.removeAll { $0.id == id }
    }

    func update(_ article: Article) async throws {
        updateCallCount += 1
        lastUpdatedArticle = article
        if shouldThrowOnUpdate {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
    }

    func updateReadPosition(articleId: UUID, position: Double) async throws {
        updateReadPositionCallCount += 1
        lastReadPositionUpdate = (articleId, position)
        if shouldThrowOnUpdateReadPosition {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        if let index = articles.firstIndex(where: { $0.id == articleId }) {
            articles[index].readPosition = position
        }
    }

    func toggleFavorite(id: UUID) async throws {
        toggleFavoriteCallCount += 1
        lastToggledFavoriteId = id
        if shouldThrowOnToggleFavorite {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        if let index = articles.firstIndex(where: { $0.id == id }) {
            articles[index].isFavorite.toggle()
        }
    }

    func toggleArchive(id: UUID) async throws {
        toggleArchiveCallCount += 1
        lastToggledArchiveId = id
        if shouldThrowOnToggleArchive {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        if let index = articles.firstIndex(where: { $0.id == id }) {
            articles[index].isArchived.toggle()
        }
    }

    func reset() {
        articles = []
        getAllCallCount = 0
        saveCallCount = 0
        deleteCallCount = 0
        updateCallCount = 0
        updateReadPositionCallCount = 0
        toggleFavoriteCallCount = 0
        toggleArchiveCallCount = 0
        shouldThrowOnGetAll = false
        shouldThrowOnSave = false
        shouldThrowOnDelete = false
        shouldThrowOnUpdate = false
        shouldThrowOnUpdateReadPosition = false
        shouldThrowOnToggleFavorite = false
        shouldThrowOnToggleArchive = false
        lastSavedArticle = nil
        lastDeletedId = nil
        lastUpdatedArticle = nil
        lastToggledFavoriteId = nil
        lastToggledArchiveId = nil
        lastReadPositionUpdate = nil
    }
}
