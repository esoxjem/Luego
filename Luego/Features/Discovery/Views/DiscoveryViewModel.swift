import Foundation

enum KagiLoadingGifRotator {
    private static let gifs = ["kagi-loading", "kagi-loading-2"]
    private static var lastIndex: Int?

    static func next() -> String {
        let availableIndices = gifs.indices.filter { $0 != lastIndex }
        let nextIndex = availableIndices.randomElement() ?? 0
        lastIndex = nextIndex
        return gifs[nextIndex]
    }
}

@Observable
@MainActor
final class DiscoveryViewModel {
    var selectedSource: DiscoverySource
    var ephemeralArticle: EphemeralArticle?
    var isLoading = false
    var errorMessage: String?
    var isSaved = false
    var pendingArticleURL: URL?
    var currentLoadingGif: String = KagiLoadingGifRotator.next()
    private var consecutiveFailures = 0

    private let saveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol
    private let articleRepository: ArticleRepositoryProtocol
    private let currentUseCase: FetchRandomArticleUseCaseProtocol

    init(
        useCaseFactory: @escaping @MainActor (DiscoverySource) -> FetchRandomArticleUseCaseProtocol,
        saveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol,
        articleRepository: ArticleRepositoryProtocol,
        preferencesDataSource: DiscoveryPreferencesDataSourceProtocol
    ) {
        self.saveDiscoveredArticleUseCase = saveDiscoveredArticleUseCase
        self.articleRepository = articleRepository

        let savedSource = preferencesDataSource.getSelectedSource()
        self.selectedSource = savedSource
        self.currentUseCase = useCaseFactory(savedSource)
    }

    func fetchRandomArticle() async {
        isLoading = true
        errorMessage = nil
        ephemeralArticle = nil
        pendingArticleURL = nil
        isSaved = false

        if selectedSource == .kagiSmallWeb {
            currentLoadingGif = KagiLoadingGifRotator.next()
        }

        do {
            let article = try await currentUseCase.execute { [weak self] url in
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

    private func checkIfAlreadySaved(url: URL) async {
        do {
            let articles = try await articleRepository.getAll()
            isSaved = articles.contains { $0.url == url }
        } catch {
            isSaved = false
        }
    }
}
