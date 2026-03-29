import Foundation
import GRDB

@MainActor
final class GRDBArticleStore: ArticleStoreProtocol {
    private let database: AppDatabase
    weak var syncEngineManager: SyncEngineManagerProtocol?

    private let visibleArticlesSQL = """
        SELECT * FROM articles
        WHERE deletedAt IS NULL
        ORDER BY savedDate DESC
        """

    init(database: AppDatabase) {
        self.database = database
    }

    func fetchAllArticles() throws -> [Article] {
        let records = try database.reader.read { db in
            try ArticleRecord.fetchAll(
                db,
                sql: self.visibleArticlesSQL
            )
        }
        return records.map { $0.toArticle() }
    }

    func fetchAllRecords() throws -> [ArticleRecord] {
        try database.reader.read { db in
            try ArticleRecord.fetchAll(
                db,
                sql: "SELECT * FROM articles ORDER BY savedDate DESC"
            )
        }
    }

    func observeArticles() -> AsyncThrowingStream<[Article], Error> {
        let observation = ValueObservation.tracking { db in
            try ArticleRecord.fetchAll(
                db,
                sql: self.visibleArticlesSQL
            )
        }

        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    for try await records in observation.values(in: database.reader) {
                        continuation.yield(records.map { $0.toArticle() })
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func fetchArticle(id: UUID) throws -> Article? {
        guard let record = try fetchRecord(id: id), record.deletedAt == nil else {
            return nil
        }
        return record.toArticle()
    }

    func fetchArticle(url: URL) throws -> Article? {
        guard let record = try fetchRecord(url: url), record.deletedAt == nil else {
            return nil
        }
        return record.toArticle()
    }

    func fetchRecord(id: UUID) throws -> ArticleRecord? {
        try fetchRecord(recordName: id.uuidString)
    }

    func fetchRecord(recordName: String) throws -> ArticleRecord? {
        try database.reader.read { db in
            try ArticleRecord.fetchOne(db, key: recordName)
        }
    }

    func fetchRecord(url: URL) throws -> ArticleRecord? {
        try database.reader.read { db in
            try ArticleRecord.fetchOne(
                db,
                sql: "SELECT * FROM articles WHERE url = ? LIMIT 1",
                arguments: [url.absoluteString]
            )
        }
    }

    func saveArticle(_ article: Article) throws -> Article {
        if let existingRecord = try fetchRecord(url: article.url),
           existingRecord.id != article.id.uuidString {
            if existingRecord.deletedAt == nil {
                return existingRecord.toArticle()
            }

            var revivedRecord = ArticleRecord(article)
            revivedRecord.id = existingRecord.id
            revivedRecord.cloudKitSystemFields = existingRecord.cloudKitSystemFields
            revivedRecord.deletedAt = nil
            try saveRecord(revivedRecord)
            syncEngineManager?.enqueueSave(for: ArticleRecord.makeRecordID(for: revivedRecord.id))
            return revivedRecord.toArticle()
        }

        var record = ArticleRecord(article)
        if let existingRecord = try fetchRecord(id: article.id) {
            record.cloudKitSystemFields = existingRecord.cloudKitSystemFields
        }
        record.deletedAt = nil

        try saveRecord(record)
        syncEngineManager?.enqueueSave(for: ArticleRecord.makeRecordID(for: record.id))
        return record.toArticle()
    }

    func insertArticle(_ article: Article) throws {
        _ = try saveArticle(article)
    }

    func saveRecord(_ record: ArticleRecord) throws {
        try database.writer.write { db in
            try record.save(db)
        }
    }

    func deleteArticle(id: UUID) throws {
        var didTombstone = false
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString),
                  record.deletedAt == nil else {
                return
            }

            record.deletedAt = Date()
            try record.save(db)
            didTombstone = true
        }
        if didTombstone {
            syncEngineManager?.enqueueSave(for: ArticleRecord.makeRecordID(for: id.uuidString))
        }
    }

    func deleteRecord(recordName: String) throws {
        try database.writer.write { db in
            _ = try ArticleRecord.deleteOne(db, key: recordName)
        }
    }

    func clearCloudKitSystemFields(recordName: String) throws {
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: recordName) else {
                return
            }

            record.cloudKitSystemFields = nil
            try record.save(db)
        }
    }

    func toggleFavorite(id: UUID) throws {
        var didUpdate = false
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString) else {
                return
            }

            guard record.deletedAt == nil else {
                return
            }

            record.isFavorite.toggle()
            if record.isFavorite {
                record.isArchived = false
            }
            try record.save(db)
            didUpdate = true
        }
        if didUpdate {
            syncEngineManager?.enqueueSave(for: ArticleRecord.makeRecordID(for: id.uuidString))
        }
    }

    func toggleArchive(id: UUID) throws {
        var didUpdate = false
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString) else {
                return
            }

            guard record.deletedAt == nil else {
                return
            }

            record.isArchived.toggle()
            if record.isArchived {
                record.isFavorite = false
            }
            try record.save(db)
            didUpdate = true
        }
        if didUpdate {
            syncEngineManager?.enqueueSave(for: ArticleRecord.makeRecordID(for: id.uuidString))
        }
    }

    func updateReadPosition(id: UUID, position: Double) throws {
        var didUpdate = false
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString) else {
                return
            }

            guard record.deletedAt == nil else {
                return
            }

            record.readPosition = position
            try record.save(db)
            didUpdate = true
        }
        if didUpdate {
            syncEngineManager?.enqueueSave(for: ArticleRecord.makeRecordID(for: id.uuidString))
        }
    }

    func countArticles() throws -> Int {
        try database.reader.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM articles WHERE deletedAt IS NULL"
            ) ?? 0
        }
    }
}
