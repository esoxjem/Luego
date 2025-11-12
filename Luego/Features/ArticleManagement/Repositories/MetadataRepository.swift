import Foundation

protocol MetadataRepositoryProtocol: Sendable {
    func validateURL(_ url: URL) async throws -> URL
    func fetchMetadata(for url: URL) async throws -> ArticleMetadata
    func fetchContent(for url: URL) async throws -> ArticleContent
}

@MainActor
final class MetadataRepository: MetadataRepositoryProtocol {
    private let metadataService: ArticleMetadataService

    init(metadataService: ArticleMetadataService = .shared) {
        self.metadataService = metadataService
    }

    func validateURL(_ url: URL) async throws -> URL {
        let urlString = url.absoluteString
        guard let validatedURL = metadataService.validateURL(urlString) else {
            throw ArticleMetadataError.invalidURL
        }
        return validatedURL
    }

    func fetchMetadata(for url: URL) async throws -> ArticleMetadata {
        try await metadataService.fetchMetadata(from: url)
    }

    func fetchContent(for url: URL) async throws -> ArticleContent {
        try await metadataService.fetchFullContent(from: url)
    }
}
