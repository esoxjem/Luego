import Foundation
import SwiftData

protocol ArticleServiceProtocol: Sendable {
    func getAllArticles() async throws -> [Article]
    func addArticle(url: URL) async throws -> Article
    func deleteArticle(id: UUID) async throws
    func updateArticle(_ article: Article) async throws
    func toggleFavorite(id: UUID) async throws
    func toggleArchive(id: UUID) async throws
    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article
}

@MainActor
final class ArticleService: ArticleServiceProtocol {
    private let modelContext: ModelContext
    private let metadataDataSource: MetadataDataSourceProtocol

    init(modelContext: ModelContext, metadataDataSource: MetadataDataSourceProtocol) {
        self.modelContext = modelContext
        self.metadataDataSource = metadataDataSource
    }

    func getAllArticles() async throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func addArticle(url: URL) async throws -> Article {
        let validatedURL = try await metadataDataSource.validateURL(url)
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
            modelContext.insert(article)
            try modelContext.save()
            return article
        } catch {
            modelContext.rollback()
            if let existingArticle = findExistingArticle(for: validatedURL) {
                Logger.article.debug("Duplicate detected via constraint: \(validatedURL.absoluteString)")
                return existingArticle
            }
            throw error
        }
    }

    func deleteArticle(id: UUID) async throws {
        guard let article = try fetchArticle(by: id) else { return }

        modelContext.delete(article)
        try modelContext.save()
    }

    func updateArticle(_ article: Article) async throws {
        try modelContext.save()
    }

    func toggleFavorite(id: UUID) async throws {
        guard let article = try fetchArticle(by: id) else { return }

        article.isFavorite.toggle()
        if article.isFavorite {
            article.isArchived = false
        }
        try modelContext.save()
    }

    func toggleArchive(id: UUID) async throws {
        guard let article = try fetchArticle(by: id) else { return }

        article.isArchived.toggle()
        if article.isArchived {
            article.isFavorite = false
        }
        try modelContext.save()
    }

    private func fetchArticle(by id: UUID) throws -> Article? {
        let predicate = #Predicate<Article> { $0.id == id }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
        if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
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
            modelContext.insert(article)
            try modelContext.save()
            return article
        } catch {
            modelContext.rollback()
            if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
                Logger.article.debug("Duplicate detected via constraint: \(ephemeralArticle.url.absoluteString)")
                return existingArticle
            }
            throw error
        }
    }

    private func findExistingArticle(for url: URL) -> Article? {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}
