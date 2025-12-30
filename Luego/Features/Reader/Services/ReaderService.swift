import Foundation
import SwiftData

protocol ReaderServiceProtocol: Sendable {
    func fetchContent(for article: Article, forceRefresh: Bool) async throws -> Article
    func updateReadPosition(articleId: UUID, position: Double) async throws
}

@MainActor
final class ReaderService: ReaderServiceProtocol {
    private let modelContext: ModelContext
    private let metadataDataSource: MetadataDataSourceProtocol

    init(modelContext: ModelContext, metadataDataSource: MetadataDataSourceProtocol) {
        self.modelContext = modelContext
        self.metadataDataSource = metadataDataSource
    }

    func fetchContent(for article: Article, forceRefresh: Bool = false) async throws -> Article {
        guard forceRefresh || article.content == nil else {
            return article
        }

        let content = try await metadataDataSource.fetchContent(for: article.url, timeout: nil, forceRefresh: forceRefresh)
        article.content = content.content

        if article.author == nil, let author = content.author {
            article.author = author
        }
        if article.wordCount == nil, let wordCount = content.wordCount {
            article.wordCount = wordCount
        }

        try modelContext.save()
        return article
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
