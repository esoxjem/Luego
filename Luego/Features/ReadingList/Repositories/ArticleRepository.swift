import Foundation
import SwiftData

protocol ArticleRepositoryProtocol: Sendable {
    func getAll() async throws -> [Article]
    func save(_ article: Article) async throws -> Article
    func delete(id: UUID) async throws
    func update(_ article: Article) async throws
    func updateReadPosition(articleId: UUID, position: Double) async throws
    func toggleFavorite(id: UUID) async throws
    func toggleArchive(id: UUID) async throws
}

@MainActor
final class ArticleRepository: ArticleRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getAll() async throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ article: Article) async throws -> Article {
        modelContext.insert(article)
        try modelContext.save()
        return article
    }

    func delete(id: UUID) async throws {
        let predicate = #Predicate<Article> { $0.id == id }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let article = try modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(article)
        try modelContext.save()
    }

    func update(_ article: Article) async throws {
        try modelContext.save()
    }

    func updateReadPosition(articleId: UUID, position: Double) async throws {
        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let article = try modelContext.fetch(descriptor).first else {
            return
        }

        article.readPosition = position
        try modelContext.save()
    }

    func toggleFavorite(id: UUID) async throws {
        try modelContext.save()
    }

    func toggleArchive(id: UUID) async throws {
        try modelContext.save()
    }
}
