import Foundation

protocol MetadataRepositoryProtocol: Sendable {
    func validateURL(_ url: URL) async throws -> URL
    func fetchMetadata(for url: URL) async throws -> ArticleMetadata
    func fetchContent(for url: URL) async throws -> ArticleContent
}

@MainActor
final class MetadataRepository: MetadataRepositoryProtocol {
    private let htmlParser: HTMLParserDataSource

    init(htmlParser: HTMLParserDataSource) {
        self.htmlParser = htmlParser
    }

    func validateURL(_ url: URL) async throws -> URL {
        let urlString = url.absoluteString
        guard let validatedURL = htmlParser.validateURL(urlString) else {
            throw ArticleMetadataError.invalidURL
        }
        return validatedURL
    }

    func fetchMetadata(for url: URL) async throws -> ArticleMetadata {
        try await htmlParser.fetchMetadata(from: url)
    }

    func fetchContent(for url: URL) async throws -> ArticleContent {
        try await htmlParser.fetchFullContent(from: url)
    }
}
