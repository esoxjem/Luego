import Foundation

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

    func fetchMetadata(for url: URL) async throws -> Domain.ArticleMetadata {
        let metadata = try await htmlParser.fetchMetadata(from: url)
        return metadata.toDomain()
    }

    func fetchContent(for url: URL) async throws -> Domain.ArticleContent {
        let content = try await htmlParser.fetchFullContent(from: url)
        return content.toDomain()
    }
}
