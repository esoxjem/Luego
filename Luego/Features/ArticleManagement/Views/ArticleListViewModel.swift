import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?

    private let getArticlesUseCase: GetArticlesUseCase
    private let addArticleUseCase: AddArticleUseCase
    private let deleteArticleUseCase: DeleteArticleUseCase
    private let syncSharedArticlesUseCase: SyncSharedArticlesUseCase

    init(
        getArticlesUseCase: GetArticlesUseCase,
        addArticleUseCase: AddArticleUseCase,
        deleteArticleUseCase: DeleteArticleUseCase,
        syncSharedArticlesUseCase: SyncSharedArticlesUseCase
    ) {
        self.getArticlesUseCase = getArticlesUseCase
        self.addArticleUseCase = addArticleUseCase
        self.deleteArticleUseCase = deleteArticleUseCase
        self.syncSharedArticlesUseCase = syncSharedArticlesUseCase
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
}
