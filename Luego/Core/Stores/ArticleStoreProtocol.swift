import Foundation

@MainActor
protocol ArticleStoreProtocol: AnyObject {
    func fetchAllArticles() throws -> [Article]
    func observeArticles() -> AsyncThrowingStream<[Article], Error>
    func fetchArticle(id: UUID) throws -> Article?
    func fetchArticle(url: URL) throws -> Article?
    func fetchRecord(id: UUID) throws -> ArticleRecord?
    func fetchRecord(url: URL) throws -> ArticleRecord?
    func saveArticle(_ article: Article) throws -> Article
    func saveRecord(_ record: ArticleRecord) throws
    func deleteArticle(id: UUID) throws
    func toggleFavorite(id: UUID) throws
    func toggleArchive(id: UUID) throws
    func updateReadPosition(id: UUID, position: Double) throws
    func countArticles() throws -> Int
}

extension ArticleStoreProtocol {
    func fetchRecord(id: UUID) throws -> ArticleRecord? {
        try fetchArticle(id: id).map { ArticleRecord($0) }
    }

    func fetchRecord(url: URL) throws -> ArticleRecord? {
        try fetchArticle(url: url).map { ArticleRecord($0) }
    }

    func saveRecord(_ record: ArticleRecord) throws {
        _ = try saveArticle(record.toArticle())
    }

    func toggleFavorite(id: UUID) throws {
        guard let article = try fetchArticle(id: id) else { return }
        article.isFavorite.toggle()
        if article.isFavorite {
            article.isArchived = false
        }
        _ = try saveArticle(article)
    }

    func toggleArchive(id: UUID) throws {
        guard let article = try fetchArticle(id: id) else { return }
        article.isArchived.toggle()
        if article.isArchived {
            article.isFavorite = false
        }
        _ = try saveArticle(article)
    }

    func countArticles() throws -> Int {
        try fetchAllArticles().count
    }
}
