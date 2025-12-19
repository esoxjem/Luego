import Foundation
import SwiftUI
import Observation

enum ArticleFilter {
    case readingList
    case favorites
    case archived
}

@Observable
@MainActor
final class ArticleListViewModel {
    var isLoading = false
    var errorMessage: String?

    private let getArticlesUseCase: GetArticlesUseCaseProtocol
    private let addArticleUseCase: AddArticleUseCaseProtocol
    private let deleteArticleUseCase: DeleteArticleUseCaseProtocol
    private let syncSharedArticlesUseCase: SyncSharedArticlesUseCaseProtocol
    private let toggleFavoriteUseCase: ToggleFavoriteUseCaseProtocol
    private let toggleArchiveUseCase: ToggleArchiveUseCaseProtocol

    init(
        getArticlesUseCase: GetArticlesUseCaseProtocol,
        addArticleUseCase: AddArticleUseCaseProtocol,
        deleteArticleUseCase: DeleteArticleUseCaseProtocol,
        syncSharedArticlesUseCase: SyncSharedArticlesUseCaseProtocol,
        toggleFavoriteUseCase: ToggleFavoriteUseCaseProtocol,
        toggleArchiveUseCase: ToggleArchiveUseCaseProtocol
    ) {
        self.getArticlesUseCase = getArticlesUseCase
        self.addArticleUseCase = addArticleUseCase
        self.deleteArticleUseCase = deleteArticleUseCase
        self.syncSharedArticlesUseCase = syncSharedArticlesUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.toggleArchiveUseCase = toggleArchiveUseCase
    }

    func addArticle(from urlString: String, existingArticles: [Article]) async {
        errorMessage = nil

        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Please enter a valid URL"
            return
        }

        if existingArticles.contains(where: { $0.url == url }) {
            errorMessage = "This article has already been saved"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await addArticleUseCase.execute(url: url)
        } catch let error as ArticleMetadataError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to save article: \(error.localizedDescription)"
        }
    }

    func deleteArticle(_ article: Article) async {
        do {
            try await deleteArticleUseCase.execute(articleId: article.id)
        } catch {
            errorMessage = "Failed to delete article: \(error.localizedDescription)"
        }
    }

    func syncSharedArticles() async {
        do {
            _ = try await syncSharedArticlesUseCase.execute()
        } catch {
            errorMessage = "Failed to sync shared articles: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func toggleFavorite(_ article: Article) async {
        do {
            try await toggleFavoriteUseCase.execute(articleId: article.id)
        } catch {
            errorMessage = "Failed to toggle favorite: \(error.localizedDescription)"
        }
    }

    func toggleArchive(_ article: Article) async {
        do {
            try await toggleArchiveUseCase.execute(articleId: article.id)
        } catch {
            errorMessage = "Failed to toggle archive: \(error.localizedDescription)"
        }
    }
}
