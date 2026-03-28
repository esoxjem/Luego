import Foundation

@MainActor
protocol SharingServiceProtocol: Sendable {
    func syncSharedArticles() async throws -> [Article]
}

@MainActor
final class SharingService: SharingServiceProtocol {
    private let articleStore: ArticleStoreProtocol
    private let metadataDataSource: MetadataDataSourceProtocol
    private let userDefaultsDataSource: UserDefaultsDataSourceProtocol

    init(
        articleStore: ArticleStoreProtocol,
        metadataDataSource: MetadataDataSourceProtocol,
        userDefaultsDataSource: UserDefaultsDataSourceProtocol
    ) {
        self.articleStore = articleStore
        self.metadataDataSource = metadataDataSource
        self.userDefaultsDataSource = userDefaultsDataSource
    }

    func syncSharedArticles() async throws -> [Article] {
        let lastSyncTimestamp = userDefaultsDataSource.getLastSyncTimestamp() ?? Date.distantPast
        let sharedURLs = userDefaultsDataSource.getSharedURLs(after: lastSyncTimestamp)

        guard !sharedURLs.isEmpty else {
            return []
        }

        var newArticles: [Article] = []
        var latestProcessedTimestamp: Date = lastSyncTimestamp

        for sharedURL in sharedURLs {
            do {
                let validatedURL = try await metadataDataSource.validateURL(sharedURL.url)

                if (try articleStore.fetchArticle(url: validatedURL)) != nil {
                    Logger.sharing.debug("Skipping duplicate URL: \(validatedURL.absoluteString)")
                    latestProcessedTimestamp = max(latestProcessedTimestamp, sharedURL.timestamp)
                    continue
                }

                let metadata = try await metadataDataSource.fetchMetadata(for: validatedURL)

                let article = Article(
                    id: UUID(),
                    url: validatedURL,
                    title: metadata.title,
                    content: nil,
                    savedDate: Date(),
                    thumbnailURL: metadata.thumbnailURL,
                    publishedDate: metadata.publishedDate,
                    readPosition: 0
                )

                do {
                    let savedArticle = try articleStore.saveArticle(article)
                    newArticles.append(savedArticle)
                    latestProcessedTimestamp = max(latestProcessedTimestamp, sharedURL.timestamp)
                } catch {
                    if let existingArticle = try articleStore.fetchArticle(url: validatedURL) {
                        Logger.sharing.debug("Duplicate detected via constraint: \(validatedURL.absoluteString)")
                        latestProcessedTimestamp = max(latestProcessedTimestamp, sharedURL.timestamp)
                        newArticles.append(existingArticle)
                    } else {
                        Logger.sharing.error("Failed to save article and no existing article found: \(error.localizedDescription)")
                    }
                }
            } catch {
                Logger.sharing.error("Failed to sync shared article from \(sharedURL.url.absoluteString): \(error.localizedDescription)")
                continue
            }
        }

        if latestProcessedTimestamp > lastSyncTimestamp {
            userDefaultsDataSource.setLastSyncTimestamp(latestProcessedTimestamp)
        }

        return newArticles
    }
}
