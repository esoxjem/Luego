import Foundation
@testable import Luego

@MainActor
final class MockArticleService: ArticleServiceProtocol {
    var getAllArticlesCallCount = 0
    var addArticleCallCount = 0
    var deleteArticleCallCount = 0
    var updateArticleCallCount = 0
    var toggleFavoriteCallCount = 0
    var toggleArchiveCallCount = 0
    var saveEphemeralArticleCallCount = 0
    var forceReSyncAllArticlesCallCount = 0

    var lastAddedURL: URL?
    var lastDeletedId: UUID?
    var lastUpdatedArticle: Article?
    var lastToggledFavoriteId: UUID?
    var lastToggledArchiveId: UUID?
    var lastSavedEphemeralArticle: EphemeralArticle?

    var articlesToReturn: [Article] = []
    var articleToReturn: Article?

    var shouldThrowOnGetAllArticles = false
    var shouldThrowOnAddArticle = false
    var shouldThrowOnDeleteArticle = false
    var shouldThrowOnUpdateArticle = false
    var shouldThrowOnToggleFavorite = false
    var shouldThrowOnToggleArchive = false
    var shouldThrowOnSaveEphemeralArticle = false
    var shouldThrowOnForceReSyncAllArticles = false
    var forceReSyncAllArticlesReturnCount = 0

    enum MockError: Error {
        case mockError
    }

    func getAllArticles() async throws -> [Article] {
        getAllArticlesCallCount += 1
        if shouldThrowOnGetAllArticles {
            throw MockError.mockError
        }
        return articlesToReturn
    }

    func addArticle(url: URL) async throws -> Article {
        addArticleCallCount += 1
        lastAddedURL = url
        if shouldThrowOnAddArticle {
            throw MockError.mockError
        }
        return articleToReturn ?? ArticleFixtures.createArticle(url: url)
    }

    func deleteArticle(id: UUID) async throws {
        deleteArticleCallCount += 1
        lastDeletedId = id
        if shouldThrowOnDeleteArticle {
            throw MockError.mockError
        }
    }

    func updateArticle(_ article: Article) async throws {
        updateArticleCallCount += 1
        lastUpdatedArticle = article
        if shouldThrowOnUpdateArticle {
            throw MockError.mockError
        }
    }

    func toggleFavorite(id: UUID) async throws {
        toggleFavoriteCallCount += 1
        lastToggledFavoriteId = id
        if shouldThrowOnToggleFavorite {
            throw MockError.mockError
        }
    }

    func toggleArchive(id: UUID) async throws {
        toggleArchiveCallCount += 1
        lastToggledArchiveId = id
        if shouldThrowOnToggleArchive {
            throw MockError.mockError
        }
    }

    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
        saveEphemeralArticleCallCount += 1
        lastSavedEphemeralArticle = ephemeralArticle
        if shouldThrowOnSaveEphemeralArticle {
            throw MockError.mockError
        }
        return articleToReturn ?? ArticleFixtures.createArticle(url: ephemeralArticle.url)
    }

    func forceReSyncAllArticles() async throws -> Int {
        forceReSyncAllArticlesCallCount += 1
        if shouldThrowOnForceReSyncAllArticles {
            throw MockError.mockError
        }
        return forceReSyncAllArticlesReturnCount
    }
}
