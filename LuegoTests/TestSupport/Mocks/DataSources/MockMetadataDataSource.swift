import Foundation
@testable import Luego

@MainActor
final class MockMetadataDataSource: MetadataDataSourceProtocol {
    var validateURLCallCount = 0
    var fetchMetadataCallCount = 0
    var fetchContentCallCount = 0
    var fetchHTMLCallCount = 0

    var lastValidatedURL: URL?
    var lastFetchMetadataURL: URL?
    var lastFetchMetadataTimeout: TimeInterval?
    var lastFetchContentURL: URL?
    var lastFetchContentTimeout: TimeInterval?
    var lastFetchContentForceRefresh: Bool?
    var lastFetchContentSkipCache: Bool?
    var lastFetchHTMLURL: URL?
    var lastFetchHTMLTimeout: TimeInterval?

    var shouldThrowOnValidateURL = false
    var shouldThrowOnFetchMetadata = false
    var shouldThrowOnFetchContent = false
    var shouldThrowOnFetchHTML = false

    var validatedURLToReturn: URL?
    var metadataToReturn: ArticleMetadata?
    var contentToReturn: ArticleContent?
    var htmlToReturn: String?

    var validateURLError: Error = ArticleMetadataError.invalidURL
    var fetchMetadataError: Error = ArticleMetadataError.noMetadata
    var fetchContentError: Error = ArticleMetadataError.noMetadata
    var fetchHTMLError: Error = ArticleMetadataError.networkError(URLError(.notConnectedToInternet))

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

    func fetchContent(for url: URL, timeout: TimeInterval?, forceRefresh: Bool, skipCache: Bool) async throws -> ArticleContent {
        fetchContentCallCount += 1
        lastFetchContentURL = url
        lastFetchContentTimeout = timeout
        lastFetchContentForceRefresh = forceRefresh
        lastFetchContentSkipCache = skipCache
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

    func fetchHTML(from url: URL, timeout: TimeInterval?) async throws -> String {
        fetchHTMLCallCount += 1
        lastFetchHTMLURL = url
        lastFetchHTMLTimeout = timeout
        if shouldThrowOnFetchHTML {
            throw fetchHTMLError
        }
        return htmlToReturn ?? "<html><body><p>Mock HTML content</p></body></html>"
    }

    func reset() {
        validateURLCallCount = 0
        fetchMetadataCallCount = 0
        fetchContentCallCount = 0
        fetchHTMLCallCount = 0
        lastValidatedURL = nil
        lastFetchMetadataURL = nil
        lastFetchMetadataTimeout = nil
        lastFetchContentURL = nil
        lastFetchContentTimeout = nil
        lastFetchContentForceRefresh = nil
        lastFetchContentSkipCache = nil
        lastFetchHTMLURL = nil
        lastFetchHTMLTimeout = nil
        shouldThrowOnValidateURL = false
        shouldThrowOnFetchMetadata = false
        shouldThrowOnFetchContent = false
        shouldThrowOnFetchHTML = false
        validatedURLToReturn = nil
        metadataToReturn = nil
        contentToReturn = nil
        htmlToReturn = nil
    }
}
