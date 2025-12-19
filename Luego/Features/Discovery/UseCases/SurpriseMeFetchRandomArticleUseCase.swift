import Foundation

@MainActor
final class SurpriseMeFetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol {
    private let kagiUseCase: FetchRandomArticleUseCaseProtocol
    private let blogrollUseCase: FetchRandomArticleUseCaseProtocol
    private var preparedSource: DiscoverySource?

    init(
        kagiUseCase: FetchRandomArticleUseCaseProtocol,
        blogrollUseCase: FetchRandomArticleUseCaseProtocol
    ) {
        self.kagiUseCase = kagiUseCase
        self.blogrollUseCase = blogrollUseCase
    }

    func prepareForFetch() -> DiscoverySource {
        let picked = DiscoverySource.concreteSources.randomElement() ?? .kagiSmallWeb
        preparedSource = picked
        return picked
    }

    func execute() async throws -> EphemeralArticle {
        try await execute(onArticleEntryFetched: { _ in })
    }

    func execute(onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle {
        let source = preparedSource ?? prepareForFetch()
        preparedSource = nil

        let useCase = source == .kagiSmallWeb ? kagiUseCase : blogrollUseCase
        return try await useCase.execute(onArticleEntryFetched: onArticleEntryFetched)
    }

    func clearCache() {
        kagiUseCase.clearCache()
        blogrollUseCase.clearCache()
    }
}
