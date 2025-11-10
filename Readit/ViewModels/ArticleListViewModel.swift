import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?

    private let metadataService = ArticleMetadataService.shared
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchArticles()
    }

    func fetchArticles() {
        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.savedDate, order: .reverse)])
        do {
            articles = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load articles: \(error.localizedDescription)"
        }
    }

    func addArticle(from urlString: String) async {
        errorMessage = nil

        guard let url = metadataService.validateURL(urlString) else {
            errorMessage = "Please enter a valid URL"
            return
        }

        if articles.contains(where: { $0.url == url }) {
            errorMessage = "This article has already been saved"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let metadata = try await metadataService.fetchMetadata(from: url)

            let article = Article(
                url: url,
                title: metadata.title,
                thumbnailURL: metadata.thumbnailURL
            )

            modelContext.insert(article)
            try modelContext.save()
            fetchArticles()

        } catch let error as ArticleMetadataError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to save article: \(error.localizedDescription)"
        }
    }

    func deleteArticle(at offsets: IndexSet) {
        for index in offsets {
            let article = articles[index]
            modelContext.delete(article)
        }

        do {
            try modelContext.save()
            fetchArticles()
        } catch {
            errorMessage = "Failed to delete article: \(error.localizedDescription)"
        }
    }

    func deleteArticle(_ article: Article) {
        modelContext.delete(article)

        do {
            try modelContext.save()
            fetchArticles()
        } catch {
            errorMessage = "Failed to delete article: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func fetchArticleContent(for article: Article) async throws -> String {
        if let content = article.content, !content.isEmpty {
            return content
        }

        let articleContent = try await metadataService.fetchFullContent(from: article.url)

        article.content = articleContent.content

        do {
            try modelContext.save()
            fetchArticles()
        } catch {
            throw error
        }

        return articleContent.content
    }
}
