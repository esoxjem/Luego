import Foundation
import SwiftData

@MainActor
final class ArticleRepository: ArticleRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getAll() async throws -> [Domain.Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        let articles = try modelContext.fetch(descriptor)
        return articles.map { $0.toDomain() }
    }

    func save(_ article: Domain.Article) async throws -> Domain.Article {
        let modelArticle = Article.fromDomain(article)
        modelContext.insert(modelArticle)
        try modelContext.save()
        return modelArticle.toDomain()
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

    func update(_ article: Domain.Article) async throws {
        let articleId = article.id
        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let existingArticle = try modelContext.fetch(descriptor).first else {
            return
        }

        existingArticle.title = article.title
        existingArticle.content = article.content
        existingArticle.thumbnailURL = article.thumbnailURL
        existingArticle.publishedDate = article.publishedDate
        existingArticle.readPosition = article.readPosition

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
}
