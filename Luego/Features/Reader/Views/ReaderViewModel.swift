import Foundation
import Observation

@Observable
@MainActor
final class ReaderViewModel {
    var article: Article
    var articleContent: String?
    var isLoading: Bool
    var errorMessage: String?

    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?
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
        Logger.reader.debug("loadContent() called for article \(article.id)")

        guard articleContent == nil else {
            Logger.reader.debug("Content already loaded, skipping")
            return
        }

        loadingTask?.cancel()
        Logger.reader.debug("Starting content load")

        isLoading = true
        errorMessage = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                let updatedArticle = try await readerService.fetchContent(for: article, forceRefresh: false)

                try Task.checkCancellation()

                article = updatedArticle
                articleContent = updatedArticle.content
                Logger.reader.debug("Content loaded successfully")
            } catch is CancellationError {
                Logger.reader.debug("loadContent cancelled for article \(article.id)")
            } catch {
                Logger.reader.error("loadContent failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }

        loadingTask = task
        await task.value
    }

    func refreshContent() async {
        Logger.reader.debug("refreshContent() called for article \(article.id)")

        loadingTask?.cancel()
        Logger.reader.debug("Starting content refresh")

        isLoading = true
        errorMessage = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                let updatedArticle = try await readerService.fetchContent(for: article, forceRefresh: true)

                try Task.checkCancellation()

                article = updatedArticle
                articleContent = updatedArticle.content
                Logger.reader.debug("Content refreshed successfully")
            } catch is CancellationError {
                Logger.reader.debug("refreshContent cancelled for article \(article.id)")
            } catch {
                Logger.reader.error("refreshContent failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }

        loadingTask = task
        await task.value
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
