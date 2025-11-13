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
    var articles: [Article] = []
    var filter: ArticleFilter = .readingList
    var isLoading = false
    var errorMessage: String?

    var filteredArticles: [Article] {
        switch filter {
        case .readingList:
            return articles.filter { !$0.isArchived }
        case .favorites:
            return articles.filter { $0.isFavorite && !$0.isArchived }
        case .archived:
            return articles.filter { $0.isArchived }
        }
    }

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

    func loadArticles() async {
        do {
            articles = try await getArticlesUseCase.execute()
        } catch {
            errorMessage = "Failed to load articles: \(error.localizedDescription)"
        }
    }

    func addArticle(from urlString: String) async {
        errorMessage = nil

        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
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
            let newArticle = try await addArticleUseCase.execute(url: url)
            articles.insert(newArticle, at: 0)
        } catch let error as ArticleMetadataError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to save article: \(error.localizedDescription)"
        }
    }

    func deleteArticle(at offsets: IndexSet) async {
        for index in offsets {
            let article = articles[index]
            do {
                try await deleteArticleUseCase.execute(articleId: article.id)
                articles.remove(at: index)
            } catch {
                errorMessage = "Failed to delete article: \(error.localizedDescription)"
                return
            }
        }
    }

    func deleteArticle(_ article: Article) async {
        do {
            try await deleteArticleUseCase.execute(articleId: article.id)
            articles.removeAll { $0.id == article.id }
        } catch {
            errorMessage = "Failed to delete article: \(error.localizedDescription)"
        }
    }

    func syncSharedArticles() async {
        do {
            let newArticles = try await syncSharedArticlesUseCase.execute()
            if !newArticles.isEmpty {
                articles.insert(contentsOf: newArticles, at: 0)
            }
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
            await loadArticles()
        } catch {
            errorMessage = "Failed to toggle favorite: \(error.localizedDescription)"
        }
    }

    func toggleArchive(_ article: Article) async {
        do {
            try await toggleArchiveUseCase.execute(articleId: article.id)
            await loadArticles()
        } catch {
            errorMessage = "Failed to toggle archive: \(error.localizedDescription)"
        }
    }

    func setFilter(_ newFilter: ArticleFilter) {
        filter = newFilter
    }
}
