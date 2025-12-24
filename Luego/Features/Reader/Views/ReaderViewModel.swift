import Foundation
import Observation

@Observable
@MainActor
final class ReaderViewModel {
    var article: Article
    var articleContent: String?
    var isLoading: Bool
    var errorMessage: String?

    private let readerService: ReaderServiceProtocol

    init(
        article: Article,
        readerService: ReaderServiceProtocol
    ) {
        self.article = article
        self.articleContent = article.content
        self.isLoading = article.content == nil
        self.readerService = readerService
    }

    func loadContent() async {
        guard articleContent == nil else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedArticle = try await readerService.fetchContent(for: article, forceRefresh: false)
            article = updatedArticle
            articleContent = updatedArticle.content
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func refreshContent() async {
        isLoading = true
        errorMessage = nil

        do {
            let updatedArticle = try await readerService.fetchContent(for: article, forceRefresh: true)
            article = updatedArticle
            articleContent = updatedArticle.content
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func updateReadPosition(_ position: Double) async {
        let clampedPosition = max(0.0, min(1.0, position))
        article.readPosition = clampedPosition

        do {
            try await readerService.updateReadPosition(articleId: article.id, position: clampedPosition)
        } catch {
            errorMessage = "Failed to save read position: \(error.localizedDescription)"
        }
    }
}
