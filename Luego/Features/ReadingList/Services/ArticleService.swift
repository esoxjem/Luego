import Foundation

@MainActor
protocol ArticleServiceProtocol: Sendable {
    func getAllArticles() async throws -> [Article]
    func observeArticles() -> AsyncThrowingStream<[Article], Error>
    func addArticle(url: URL) async throws -> Article
    func deleteArticle(id: UUID) async throws
    func updateArticle(_ article: Article) async throws
    func toggleFavorite(id: UUID) async throws
    func toggleArchive(id: UUID) async throws
    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article
    func forceReSyncAllArticles() async throws -> Int
}

@MainActor
final class ArticleService: ArticleServiceProtocol {
    private let articleStore: ArticleStoreProtocol
    private let metadataDataSource: MetadataDataSourceProtocol
    private let syncEngineManager: SyncEngineManagerProtocol

    init(
        articleStore: ArticleStoreProtocol,
        metadataDataSource: MetadataDataSourceProtocol,
        syncEngineManager: SyncEngineManagerProtocol
    ) {
        self.articleStore = articleStore
        self.metadataDataSource = metadataDataSource
        self.syncEngineManager = syncEngineManager
    }

    func getAllArticles() async throws -> [Article] {
        try articleStore.fetchAllArticles()
    }

    func observeArticles() -> AsyncThrowingStream<[Article], Error> {
        articleStore.observeArticles()
    }

    func addArticle(url: URL) async throws -> Article {
        let validatedURL = try await metadataDataSource.validateURL(url)

        if let existingArticle = try articleStore.fetchArticle(url: validatedURL) {
            Logger.article.debug("Duplicate detected: \(validatedURL.absoluteString)")
            return existingArticle
        }

        let metadata = try await metadataDataSource.fetchMetadata(for: validatedURL)

        let article = Article(
            id: UUID(),
            url: validatedURL,
            title: metadata.title,
            content: nil,
            savedDate: Date(),
            thumbnailURL: metadata.thumbnailURL,
            publishedDate: metadata.publishedDate,
            readPosition: 0
        )

        Logger.article.debug("[ThumbnailDebug] Article Storage - URL: \(validatedURL.absoluteString)")
        Logger.article.debug("[ThumbnailDebug] Article Storage - thumbnailURL: \(metadata.thumbnailURL?.absoluteString ?? "nil")")

        do {
            return try articleStore.saveArticle(article)
        } catch {
            if let existingArticle = try articleStore.fetchArticle(url: validatedURL) {
                Logger.article.debug("Duplicate detected after error: \(validatedURL.absoluteString)")
                return existingArticle
            }
            throw error
        }
    }

    func deleteArticle(id: UUID) async throws {
        try articleStore.deleteArticle(id: id)
    }

    func updateArticle(_ article: Article) async throws {
        _ = try articleStore.saveArticle(article)
    }

    func toggleFavorite(id: UUID) async throws {
        guard let article = try articleStore.fetchArticle(id: id) else {
            return
        }

        article.isFavorite.toggle()
        if article.isFavorite {
            article.isArchived = false
        }

        _ = try articleStore.saveArticle(article)
    }

    func toggleArchive(id: UUID) async throws {
        guard let article = try articleStore.fetchArticle(id: id) else {
            return
        }

        article.isArchived.toggle()
        if article.isArchived {
            article.isFavorite = false
        }

        _ = try articleStore.saveArticle(article)
    }

    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
        if let existingArticle = try articleStore.fetchArticle(url: ephemeralArticle.url) {
            return existingArticle
        }

        let article = Article(
            url: ephemeralArticle.url,
            title: ephemeralArticle.title,
            content: ephemeralArticle.content,
            thumbnailURL: ephemeralArticle.thumbnailURL,
            publishedDate: ephemeralArticle.publishedDate
        )

        do {
            return try articleStore.saveArticle(article)
        } catch {
            if let existingArticle = try articleStore.fetchArticle(url: ephemeralArticle.url) {
                Logger.article.debug("Duplicate detected via constraint: \(ephemeralArticle.url.absoluteString)")
                return existingArticle
            }
            throw error
        }
    }

    func forceReSyncAllArticles() async throws -> Int {
        syncEngineManager.logWatchedRecordSummary(context: "repairSync:start")

        do {
            try await syncEngineManager.resetSyncStateForFullRefetch()
            try await syncEngineManager.fetchChanges()
            _ = try await syncEngineManager.backfillAllArticlesFromServer()
            let records = try articleStore.fetchAllRecords()

            for record in records {
                syncEngineManager.enqueueSave(for: ArticleRecord.makeRecordID(for: record.id))
            }

            try await syncEngineManager.sendChanges()
            try await syncEngineManager.fetchChanges()
            syncEngineManager.logWatchedRecordSummary(context: "repairSync:complete")
            return records.count
        } catch {
            syncEngineManager.logWatchedRecordSummary(context: "repairSync:failed")
            throw error
        }
    }
}
