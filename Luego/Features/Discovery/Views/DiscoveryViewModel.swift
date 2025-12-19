import Foundation

@Observable
@MainActor
final class DiscoveryViewModel {
    var ephemeralArticle: EphemeralArticle?
    var isLoading = false
    var errorMessage: String?
    var isSaved = false
    var selectedImageURL: URL?
    var pendingArticleURL: URL?
    private var consecutiveFailures = 0

    private let fetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol
    private let saveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol
    private let articleRepository: ArticleRepositoryProtocol

    init(
        fetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol,
        saveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol,
        articleRepository: ArticleRepositoryProtocol
    ) {
        self.fetchRandomArticleUseCase = fetchRandomArticleUseCase
        self.saveDiscoveredArticleUseCase = saveDiscoveredArticleUseCase
        self.articleRepository = articleRepository
    }

    func fetchRandomArticle() async {
        isLoading = true
        errorMessage = nil
        ephemeralArticle = nil
        pendingArticleURL = nil
        isSaved = false

        do {
            let article = try await fetchRandomArticleUseCase.execute { [weak self] url in
                self?.pendingArticleURL = url
            }
            consecutiveFailures = 0
            pendingArticleURL = nil
            ephemeralArticle = article
            await checkIfAlreadySaved(url: article.url)
        } catch {
            consecutiveFailures += 1
            pendingArticleURL = nil
            if consecutiveFailures < 5 {
                await fetchRandomArticle()
                return
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func saveToReadingList() async {
        guard let article = ephemeralArticle else { return }

        do {
            _ = try await saveDiscoveredArticleUseCase.execute(ephemeralArticle: article)
            isSaved = true
        } catch {
            errorMessage = "Failed to save article"
        }
    }

    func loadAnotherArticle() async {
        await fetchRandomArticle()
    }

    func forceRefresh() async {
        fetchRandomArticleUseCase.clearCache()
        await fetchRandomArticle()
    }

    private func checkIfAlreadySaved(url: URL) async {
        do {
            let articles = try await articleRepository.getAll()
            isSaved = articles.contains { $0.url == url }
        } catch {
            isSaved = false
        }
    }
}
