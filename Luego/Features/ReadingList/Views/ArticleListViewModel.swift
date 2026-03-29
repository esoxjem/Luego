import Foundation
import Observation

@Observable
@MainActor
final class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?

    private let articleService: ArticleServiceProtocol
    private let sharingService: SharingServiceProtocol
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    init(
        articleService: ArticleServiceProtocol,
        sharingService: SharingServiceProtocol
    ) {
        self.articleService = articleService
        self.sharingService = sharingService
        self.articles = []
    }

    deinit {
        observationTask?.cancel()
    }

    func startObservingArticles() {
        guard observationTask == nil else { return }

        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                observationTask = nil
            }

            do {
                for try await articles in articleService.observeArticles() {
                    self.articles = articles
                }
            } catch is CancellationError {
            } catch {
                self.errorMessage = "Failed to observe articles: \(error.localizedDescription)"
            }
        }
    }

    func addArticle(from urlString: String) async {
        errorMessage = nil

        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Please enter a valid URL"
            return
        }

        let currentArticles = articles.isEmpty ? (try? await articleService.getAllArticles()) ?? [] : articles

        if currentArticles.contains(where: { $0.url == url }) {
            errorMessage = "This article has already been saved"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await articleService.addArticle(url: url)
        } catch let error as ArticleMetadataError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to save article: \(error.localizedDescription)"
        }
    }

    func deleteArticle(_ article: Article) async {
        do {
            try await articleService.deleteArticle(id: article.id)
        } catch {
            errorMessage = "Failed to delete article: \(error.localizedDescription)"
        }
    }

    func syncSharedArticles() async {
        do {
            _ = try await sharingService.syncSharedArticles()
        } catch {
            errorMessage = "Failed to sync shared articles: \(error.localizedDescription)"
        }
    }

    func refreshArticles() async {
        do {
            try await articleService.refreshArticles()
        } catch {
            errorMessage = "Failed to refresh articles: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func toggleFavorite(_ article: Article) async {
        do {
            try await articleService.toggleFavorite(id: article.id)
        } catch {
            errorMessage = "Failed to toggle favorite: \(error.localizedDescription)"
        }
    }

    func toggleArchive(_ article: Article) async {
        do {
            try await articleService.toggleArchive(id: article.id)
        } catch {
            errorMessage = "Failed to toggle archive: \(error.localizedDescription)"
        }
    }
}
