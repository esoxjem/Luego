import Foundation
@testable import Luego

@MainActor
final class MockMetadataRepository: MetadataRepositoryProtocol {
    var validateURLCallCount = 0
    var fetchMetadataCallCount = 0
    var fetchContentCallCount = 0

    var shouldThrowOnValidate = false
    var shouldThrowOnFetchMetadata = false
    var shouldThrowOnFetchContent = false

    var validatedURLToReturn: URL?
    var metadataToReturn: ArticleMetadata?
    var contentToReturn: ArticleContent?

    var lastValidatedURL: URL?
    var lastMetadataURL: URL?
    var lastContentURL: URL?
    var lastMetadataTimeout: TimeInterval?
    var lastContentTimeout: TimeInterval?

    func validateURL(_ url: URL) async throws -> URL {
        validateURLCallCount += 1
        lastValidatedURL = url
        if shouldThrowOnValidate {
            throw ArticleMetadataError.invalidURL
        }
        return validatedURLToReturn ?? url
    }

    func fetchMetadata(for url: URL, timeout: TimeInterval?) async throws -> ArticleMetadata {
        fetchMetadataCallCount += 1
        lastMetadataURL = url
        lastMetadataTimeout = timeout
        if shouldThrowOnFetchMetadata {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        return metadataToReturn ?? ArticleMetadata(
            title: "Test Title",
            thumbnailURL: nil,
            description: "Test Description",
            publishedDate: Date()
        )
    }

    func fetchContent(for url: URL, timeout: TimeInterval?) async throws -> ArticleContent {
        fetchContentCallCount += 1
        lastContentURL = url
        lastContentTimeout = timeout
        if shouldThrowOnFetchContent {
            throw ArticleMetadataError.noMetadata
        }
        return contentToReturn ?? ArticleContent(
            title: "Test Title",
            thumbnailURL: nil,
            description: "Test Description",
            content: "Test content body with enough text to pass validation checks.",
            publishedDate: Date()
        )
    }

    func reset() {
        validateURLCallCount = 0
        fetchMetadataCallCount = 0
        fetchContentCallCount = 0
        shouldThrowOnValidate = false
        shouldThrowOnFetchMetadata = false
        shouldThrowOnFetchContent = false
        validatedURLToReturn = nil
        metadataToReturn = nil
        contentToReturn = nil
        lastValidatedURL = nil
        lastMetadataURL = nil
        lastContentURL = nil
        lastMetadataTimeout = nil
        lastContentTimeout = nil
    }
}
