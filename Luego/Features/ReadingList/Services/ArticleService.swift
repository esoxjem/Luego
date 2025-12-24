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

        modelContext.insert(article)
        try modelContext.save()
        return article
    }

    func deleteArticle(id: UUID) async throws {
        let predicate = #Predicate<Article> { $0.id == id }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let article = try modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(article)
        try modelContext.save()
    }

    func updateArticle(_ article: Article) async throws {
        try modelContext.save()
    }

    func toggleFavorite(id: UUID) async throws {
        let predicate = #Predicate<Article> { $0.id == id }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let article = try modelContext.fetch(descriptor).first else {
            return
        }

        article.isFavorite.toggle()
        try modelContext.save()
    }

    func toggleArchive(id: UUID) async throws {
        let predicate = #Predicate<Article> { $0.id == id }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let article = try modelContext.fetch(descriptor).first else {
            return
        }

        article.isArchived.toggle()
        try modelContext.save()
    }

    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
        let article = Article(
            url: ephemeralArticle.url,
            title: ephemeralArticle.title,
            content: ephemeralArticle.content,
            thumbnailURL: ephemeralArticle.thumbnailURL,
            publishedDate: ephemeralArticle.publishedDate
        )

        modelContext.insert(article)
        try modelContext.save()
        return article
    }
}
