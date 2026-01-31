import Foundation
import SwiftData

@MainActor
protocol SharingServiceProtocol: Sendable {
    func syncSharedArticles() async throws -> [Article]
}

@MainActor
final class SharingService: SharingServiceProtocol {
    private let modelContext: ModelContext
    private let metadataDataSource: MetadataDataSourceProtocol
    private let userDefaultsDataSource: UserDefaultsDataSourceProtocol

    init(
        modelContext: ModelContext,
        metadataDataSource: MetadataDataSourceProtocol,
        userDefaultsDataSource: UserDefaultsDataSourceProtocol
    ) {
        self.modelContext = modelContext
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

                if articleExists(for: validatedURL) {
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
                    modelContext.insert(article)
                    try modelContext.save()
                    newArticles.append(article)
                    latestProcessedTimestamp = max(latestProcessedTimestamp, sharedURL.timestamp)
                } catch {
                    modelContext.rollback()
                    if fetchExistingArticle(for: validatedURL) != nil {
                        Logger.sharing.debug("Duplicate detected via constraint: \(validatedURL.absoluteString)")
                        latestProcessedTimestamp = max(latestProcessedTimestamp, sharedURL.timestamp)
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

    private func articleExists(for url: URL) -> Bool {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func fetchExistingArticle(for url: URL) -> Article? {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}
