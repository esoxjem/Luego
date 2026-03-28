import Foundation
import GRDB

@MainActor
final class GRDBArticleStore: ArticleStoreProtocol {
    private let database: AppDatabase
    weak var syncEngineManager: SyncEngineManagerProtocol?

    init(database: AppDatabase) {
        self.database = database
    }

    func fetchAllArticles() throws -> [Article] {
        try database.reader.read { db in
            try ArticleRecord.fetchAll(
                db,
                sql: "SELECT * FROM articles ORDER BY savedDate DESC"
            ).map { $0.toArticle() }
        }
    }

    func observeArticles() -> AsyncThrowingStream<[Article], Error> {
        let observation = ValueObservation.tracking { db in
            try ArticleRecord.fetchAll(
                db,
                sql: "SELECT * FROM articles ORDER BY savedDate DESC"
            ).map { $0.toArticle() }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await articles in observation.values(in: database.reader) {
                        continuation.yield(articles)
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
        try fetchRecord(id: id)?.toArticle()
    }

    func fetchArticle(url: URL) throws -> Article? {
        try fetchRecord(url: url)?.toArticle()
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
        if let existing = try fetchArticle(url: article.url),
           existing.id != article.id {
            return existing
        }

        var record = ArticleRecord(article)
        if let existingRecord = try fetchRecord(id: article.id) {
            record.cloudKitSystemFields = existingRecord.cloudKitSystemFields
        }

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
        try deleteRecord(recordName: id.uuidString)
        syncEngineManager?.enqueueDelete(for: ArticleRecord.makeRecordID(for: id.uuidString))
    }

    func deleteRecord(recordName: String) throws {
        try database.writer.write { db in
            _ = try ArticleRecord.deleteOne(db, key: recordName)
        }
    }

    func toggleFavorite(id: UUID) throws {
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString) else {
                return
            }

            record.isFavorite.toggle()
            if record.isFavorite {
                record.isArchived = false
            }
            try record.save(db)
        }
    }

    func toggleArchive(id: UUID) throws {
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString) else {
                return
            }

            record.isArchived.toggle()
            if record.isArchived {
                record.isFavorite = false
            }
            try record.save(db)
        }
    }

    func updateReadPosition(id: UUID, position: Double) throws {
        try database.writer.write { db in
            guard var record = try ArticleRecord.fetchOne(db, key: id.uuidString) else {
                return
            }

            record.readPosition = position
            try record.save(db)
        }
    }

    func countArticles() throws -> Int {
        try database.reader.read { db in
            try ArticleRecord.fetchCount(db)
        }
    }
}
