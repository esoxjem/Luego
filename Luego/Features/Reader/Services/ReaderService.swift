import Foundation
import SwiftData

enum ReaderServiceError: Error, LocalizedError {
    case articleNotFound

    var errorDescription: String? {
        switch self {
        case .articleNotFound:
            return "Article not found in database"
        }
    }
}

@MainActor
protocol ReaderServiceProtocol: Sendable {
    func fetchContent(for article: Article, forceRefresh: Bool) async throws -> Article
    func updateReadPosition(articleId: UUID, position: Double) async throws
    func createHighlight(for article: Article, range: NSRange, text: String, color: HighlightColor) throws -> Highlight
    func deleteHighlight(_ highlight: Highlight) throws
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
        let articleId = article.id

        Logger.reader.debug("fetchContent() called for article \(articleId)")

        guard forceRefresh || article.content == nil else {
            Logger.reader.debug("Content already exists, returning cached")
            return article
        }

        Logger.reader.debug("Fetching content from metadata source")
        let content = try await metadataDataSource.fetchContent(for: article.url, timeout: nil, forceRefresh: forceRefresh)

        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let freshArticle = try modelContext.fetch(descriptor).first else {
            Logger.reader.error("Article \(articleId) not found after fetch")
            throw ReaderServiceError.articleNotFound
        }

        if forceRefresh || freshArticle.content == nil, !content.content.isEmpty {
            freshArticle.content = content.content
        }

        if forceRefresh || freshArticle.author == nil, let author = content.author {
            freshArticle.author = author
        }
        if forceRefresh || freshArticle.wordCount == nil, let wordCount = content.wordCount {
            freshArticle.wordCount = wordCount
        }
        if forceRefresh || freshArticle.thumbnailURL == nil, let thumbnailURL = content.thumbnailURL {
            freshArticle.thumbnailURL = thumbnailURL
        }

        try modelContext.save()
        Logger.reader.debug("Content saved for article \(articleId)")
        return freshArticle
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

    func createHighlight(for article: Article, range: NSRange, text: String, color: HighlightColor) throws -> Highlight {
        let highlight = Highlight(range: range, text: text, color: color)
        highlight.article = article
        article.highlights.append(highlight)
        try modelContext.save()
        return highlight
    }

    func deleteHighlight(_ highlight: Highlight) throws {
        if let article = highlight.article {
            article.highlights.removeAll { $0.id == highlight.id }
        }
        modelContext.delete(highlight)
        try modelContext.save()
    }
}
