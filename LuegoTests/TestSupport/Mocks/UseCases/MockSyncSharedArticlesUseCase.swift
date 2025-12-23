import Foundation
@testable import Luego

@MainActor
final class MockSyncSharedArticlesUseCase: SyncSharedArticlesUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var articlesToReturn: [Article] = []

    func execute() async throws -> [Article] {
        executeCallCount += 1
        if shouldThrow {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
        return articlesToReturn
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        articlesToReturn = []
    }
}
