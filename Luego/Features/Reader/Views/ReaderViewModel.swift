import Foundation
import Observation

@Observable
@MainActor
final class ReaderViewModel {
    var article: Article
    var articleContent: String?
    var isLoading: Bool
    var errorMessage: String?

    private let fetchContentUseCase: FetchArticleContentUseCase
    private let updateReadPositionUseCase: UpdateArticleReadPositionUseCase

    init(
        article: Article,
        fetchContentUseCase: FetchArticleContentUseCase,
        updateReadPositionUseCase: UpdateArticleReadPositionUseCase
    ) {
        self.article = article
        self.articleContent = article.content
        self.isLoading = article.content == nil
        self.fetchContentUseCase = fetchContentUseCase
        self.updateReadPositionUseCase = updateReadPositionUseCase
    }

    func loadContent() async {
        guard articleContent == nil else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedArticle = try await fetchContentUseCase.execute(article: article)
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
            try await updateReadPositionUseCase.execute(articleId: article.id, position: clampedPosition)
        } catch {
            errorMessage = "Failed to save read position: \(error.localizedDescription)"
        }
    }
}
