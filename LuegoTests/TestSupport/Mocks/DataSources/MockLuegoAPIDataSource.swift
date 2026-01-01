import Foundation
@testable import Luego

@MainActor
final class MockLuegoAPIDataSource: LuegoAPIDataSourceProtocol {
    var fetchArticleCallCount = 0
    var lastFetchedURL: URL?

    var shouldThrowError = false
    var errorToThrow: LuegoAPIError = .serviceUnavailable

    var responseToReturn: LuegoAPIResponse?

    func fetchArticle(for url: URL) async throws -> LuegoAPIResponse {
        fetchArticleCallCount += 1
        lastFetchedURL = url

        if shouldThrowError {
            throw errorToThrow
        }

        return responseToReturn ?? LuegoAPIResponse(
            content: "# Mock Article\n\nMock content from API",
            metadata: LuegoAPIMetadata(
                title: "Mock API Title",
                author: "Mock Author",
                publishedDate: "2024-12-28T10:30:00Z",
                estimatedReadTimeMinutes: 5,
                wordCount: 1000,
                sourceUrl: url.absoluteString,
                domain: url.host() ?? "example.com",
                thumbnail: nil
            )
        )
    }

    func reset() {
        fetchArticleCallCount = 0
        lastFetchedURL = nil
        shouldThrowError = false
        errorToThrow = .serviceUnavailable
        responseToReturn = nil
    }
}
