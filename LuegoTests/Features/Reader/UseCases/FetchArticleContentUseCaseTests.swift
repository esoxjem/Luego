import Testing
import Foundation
@testable import Luego

@Suite("FetchArticleContentUseCase Tests")
@MainActor
struct FetchArticleContentUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var mockMetadataRepository: MockMetadataRepository
    var useCase: FetchArticleContentUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        mockMetadataRepository = MockMetadataRepository()
        useCase = FetchArticleContentUseCase(
            articleRepository: mockArticleRepository,
            metadataRepository: mockMetadataRepository
        )
    }

    @Test("execute returns article unchanged when content exists and forceRefresh is false")
    func executeReturnsUnchangedWhenContentExists() async throws {
        let article = ArticleFixtures.createArticle(content: "Existing content")

        let result = try await useCase.execute(article: article, forceRefresh: false)

        #expect(result.content == "Existing content")
        #expect(mockMetadataRepository.fetchContentCallCount == 0)
    }

    @Test("execute fetches content when article has no content")
    func executeFetchesContentWhenMissing() async throws {
        let article = ArticleFixtures.createArticle(content: nil)
        mockMetadataRepository.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            content: "Fetched content",
            publishedDate: nil
        )

        let result = try await useCase.execute(article: article, forceRefresh: false)

        #expect(result.content == "Fetched content")
        #expect(mockMetadataRepository.fetchContentCallCount == 1)
    }

    @Test("execute fetches content when forceRefresh is true even if content exists")
    func executeFetchesContentOnForceRefresh() async throws {
        let article = ArticleFixtures.createArticle(content: "Old content")
        mockMetadataRepository.contentToReturn = ArticleContent(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            content: "New content",
            publishedDate: nil
        )

        let result = try await useCase.execute(article: article, forceRefresh: true)

        #expect(result.content == "New content")
        #expect(mockMetadataRepository.fetchContentCallCount == 1)
    }

    @Test("execute updates article in repository after fetching content")
    func executeUpdatesRepository() async throws {
        let article = ArticleFixtures.createArticle(content: nil)

        _ = try await useCase.execute(article: article, forceRefresh: false)

        #expect(mockArticleRepository.updateCallCount == 1)
    }

    @Test("execute does not update repository when content already exists")
    func executeDoesNotUpdateWhenContentExists() async throws {
        let article = ArticleFixtures.createArticle(content: "Existing content")

        _ = try await useCase.execute(article: article, forceRefresh: false)

        #expect(mockArticleRepository.updateCallCount == 0)
    }

    @Test("execute uses article URL for content fetch")
    func executeUsesArticleURL() async throws {
        let url = URL(string: "https://example.com/specific")!
        let article = ArticleFixtures.createArticle(url: url, content: nil)

        _ = try await useCase.execute(article: article, forceRefresh: false)

        #expect(mockMetadataRepository.lastContentURL == url)
    }

    @Test("execute throws when content fetch fails")
    func executeThrowsOnFetchFailure() async throws {
        let article = ArticleFixtures.createArticle(content: nil)
        mockMetadataRepository.shouldThrowOnFetchContent = true

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(article: article, forceRefresh: false)
        }
    }

    @Test("execute throws when repository update fails")
    func executeThrowsOnUpdateFailure() async throws {
        let article = ArticleFixtures.createArticle(content: nil)
        mockArticleRepository.shouldThrowOnUpdate = true

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(article: article, forceRefresh: false)
        }
    }
}
