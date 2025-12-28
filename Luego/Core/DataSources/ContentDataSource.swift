import Foundation

final class ContentDataSource: MetadataDataSourceProtocol, Sendable {
    private let luegoAPIDataSource: LuegoAPIDataSourceProtocol
    private let metadataDataSource: MetadataDataSourceProtocol

    init(
        luegoAPIDataSource: LuegoAPIDataSourceProtocol,
        metadataDataSource: MetadataDataSourceProtocol
    ) {
        self.luegoAPIDataSource = luegoAPIDataSource
        self.metadataDataSource = metadataDataSource
    }

    func validateURL(_ url: URL) async throws -> URL {
        try await metadataDataSource.validateURL(url)
    }

    func fetchMetadata(for url: URL, timeout: TimeInterval?) async throws -> ArticleMetadata {
        try await metadataDataSource.fetchMetadata(for: url, timeout: timeout)
    }

    func fetchContent(for url: URL, timeout: TimeInterval?) async throws -> ArticleContent {
        do {
            let response = try await luegoAPIDataSource.fetchArticle(for: url)

            #if DEBUG
            print("[ContentDataSource] API success for: \(url.absoluteString)")
            #endif

            let publishedDate = parsePublishedDate(from: response.metadata.publishedDate)

            return ArticleContent(
                title: response.metadata.title ?? url.host() ?? url.absoluteString,
                thumbnailURL: nil,
                description: nil,
                content: response.content,
                publishedDate: publishedDate,
                author: response.metadata.author,
                wordCount: response.metadata.wordCount
            )
        } catch {
            #if DEBUG
            print("[ContentDataSource] API failed, falling back to local parsing: \(error.localizedDescription)")
            #endif

            return try await metadataDataSource.fetchContent(for: url, timeout: timeout)
        }
    }

    private func parsePublishedDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
