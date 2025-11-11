import Foundation

@MainActor
final class HTMLParserDataSource {
    private let metadataService: ArticleMetadataService

    init(metadataService: ArticleMetadataService = .shared) {
        self.metadataService = metadataService
    }

    func validateURL(_ urlString: String) -> URL? {
        metadataService.validateURL(urlString)
    }

    func fetchMetadata(from url: URL) async throws -> ArticleMetadata {
        try await metadataService.fetchMetadata(from: url)
    }

    func fetchFullContent(from url: URL) async throws -> ArticleContent {
        try await metadataService.fetchFullContent(from: url)
    }
}
