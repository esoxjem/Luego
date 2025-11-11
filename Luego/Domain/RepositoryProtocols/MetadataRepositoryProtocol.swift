import Foundation

protocol MetadataRepositoryProtocol: Sendable {
    func validateURL(_ url: URL) async throws -> URL
    func fetchMetadata(for url: URL) async throws -> Domain.ArticleMetadata
    func fetchContent(for url: URL) async throws -> Domain.ArticleContent
}
