import Foundation
@testable import Luego

@MainActor
final class MockToggleFavoriteUseCase: ToggleFavoriteUseCaseProtocol {
    var executeCallCount = 0
    var shouldThrow = false
    var lastToggledId: UUID?

    func execute(articleId: UUID) async throws {
        executeCallCount += 1
        lastToggledId = articleId
        if shouldThrow {
            throw ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))
        }
    }

    func reset() {
        executeCallCount = 0
        shouldThrow = false
        lastToggledId = nil
    }
}
