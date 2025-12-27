import Foundation
@testable import Luego

@MainActor
final class MockMetadataDataSource: MetadataDataSourceProtocol {
    var validateURLCallCount = 0
    var fetchMetadataCallCount = 0
    var fetchContentCallCount = 0

    var lastValidatedURL: URL?
    var lastFetchMetadataURL: URL?
    var lastFetchMetadataTimeout: TimeInterval?
    var lastFetchContentURL: URL?
    var lastFetchContentTimeout: TimeInterval?

    var shouldThrowOnValidateURL = false
    var shouldThrowOnFetchMetadata = false
    var shouldThrowOnFetchContent = false

    var validatedURLToReturn: URL?
    var metadataToReturn: ArticleMetadata?
    var contentToReturn: ArticleContent?

    var validateURLError: Error = ArticleMetadataError.invalidURL
    var fetchMetadataError: Error = ArticleMetadataError.noMetadata
    var fetchContentError: Error = ArticleMetadataError.noMetadata

    func validateURL(_ url: URL) async throws -> URL {
        validateURLCallCount += 1
        lastValidatedURL = url
        if shouldThrowOnValidateURL {
            throw validateURLError
        }
        return validatedURLToReturn ?? url
    }

    func fetchMetadata(for url: URL, timeout: TimeInterval?) async throws -> ArticleMetadata {
        fetchMetadataCallCount += 1
        lastFetchMetadataURL = url
        lastFetchMetadataTimeout = timeout
        if shouldThrowOnFetchMetadata {
            throw fetchMetadataError
        }
        return metadataToReturn ?? ArticleMetadata(
            title: "Mock Title",
            thumbnailURL: nil,
            description: "Mock description",
            publishedDate: Date()
        )
    }

    func fetchContent(for url: URL, timeout: TimeInterval?) async throws -> ArticleContent {
        fetchContentCallCount += 1
        lastFetchContentURL = url
        lastFetchContentTimeout = timeout
        if shouldThrowOnFetchContent {
            throw fetchContentError
        }
        return contentToReturn ?? ArticleContent(
            title: "Mock Title",
            thumbnailURL: nil,
            description: "Mock description",
            content: "Mock content that is long enough to pass validation checks in the real implementation",
            publishedDate: Date()
        )
    }

    func reset() {
        validateURLCallCount = 0
        fetchMetadataCallCount = 0
        fetchContentCallCount = 0
        lastValidatedURL = nil
        lastFetchMetadataURL = nil
        lastFetchMetadataTimeout = nil
        lastFetchContentURL = nil
        lastFetchContentTimeout = nil
        shouldThrowOnValidateURL = false
        shouldThrowOnFetchMetadata = false
        shouldThrowOnFetchContent = false
        validatedURLToReturn = nil
        metadataToReturn = nil
        contentToReturn = nil
    }
}
