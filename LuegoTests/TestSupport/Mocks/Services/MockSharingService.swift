import Foundation
@testable import Luego

@MainActor
final class MockSharingService: SharingServiceProtocol {
    var syncSharedArticlesCallCount = 0

    var articlesToReturn: [Article] = []
    var shouldThrowOnSyncSharedArticles = false

    enum MockError: Error {
        case mockError
    }

    func syncSharedArticles() async throws -> [Article] {
        syncSharedArticlesCallCount += 1
        if shouldThrowOnSyncSharedArticles {
            throw MockError.mockError
        }
        return articlesToReturn
    }
}
