import Foundation
import SwiftData

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
        let sharedURLs = getSharedURLs()
        guard !sharedURLs.isEmpty else {
            return []
        }

        var newArticles: [Article] = []

        for url in sharedURLs {
            do {
                let validatedURL = try await metadataDataSource.validateURL(url)

                if articleExists(for: validatedURL) {
                    Logger.sharing.debug("Skipping duplicate URL: \(validatedURL.absoluteString)")
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

                modelContext.insert(article)
                try modelContext.save()
                newArticles.append(article)
            } catch {
                Logger.sharing.error("Failed to sync shared article from \(url.absoluteString): \(error.localizedDescription)")
                continue
            }
        }

        clearSharedURLs()
        return newArticles
    }

    private func getSharedURLs() -> [URL] {
        userDefaultsDataSource.getSharedURLs()
    }

    private func clearSharedURLs() {
        userDefaultsDataSource.clearSharedURLs()
    }

    private func articleExists(for url: URL) -> Bool {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first) != nil
    }
}
