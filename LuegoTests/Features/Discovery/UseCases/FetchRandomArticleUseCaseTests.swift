import Testing
import Foundation
@testable import Luego

@Suite("FetchRandomArticleUseCase Tests")
@MainActor
struct FetchRandomArticleUseCaseTests {
    var mockSourceRepository: MockDiscoverySourceRepository
    var mockMetadataRepository: MockMetadataRepository
    var useCase: FetchRandomArticleUseCase

    init() {
        mockSourceRepository = MockDiscoverySourceRepository(source: .kagiSmallWeb)
        mockMetadataRepository = MockMetadataRepository()
        useCase = FetchRandomArticleUseCase(
            source: .kagiSmallWeb,
            sourceRepository: mockSourceRepository,
            metadataRepository: mockMetadataRepository
        )
    }

    @Test("execute returns ephemeral article from source")
    func executeReturnsEphemeralArticle() async throws {
        let articleEntry = SmallWebArticleEntry(
            title: "Test Article",
            articleUrl: URL(string: "https://example.com/article")!,
            htmlUrl: nil
        )
        mockSourceRepository.randomArticleToReturn = articleEntry
        mockMetadataRepository.contentToReturn = ArticleContent(
            title: "Test Article",
            thumbnailURL: nil,
            description: nil,
            content: "Article content",
            publishedDate: nil
        )

        let result = try await useCase.execute()

        #expect(result.title == "Test Article")
        #expect(result.content == "Article content")
    }

    @Test("execute fetches content with 10 second timeout")
    func executeFetchesWithTimeout() async throws {
        let articleEntry = SmallWebArticleEntry(
            title: "Test",
            articleUrl: URL(string: "https://example.com")!,
            htmlUrl: nil
        )
        mockSourceRepository.randomArticleToReturn = articleEntry

        _ = try await useCase.execute()

        #expect(mockMetadataRepository.lastContentTimeout == 10)
    }

    @Test("prepareForFetch returns source")
    func prepareForFetchReturnsSource() {
        let source = useCase.prepareForFetch()

        #expect(source == .kagiSmallWeb)
    }

    @Test("clearCache delegates to source repository")
    func clearCacheDelegatesToRepository() {
        useCase.clearCache()

        #expect(mockSourceRepository.clearCacheCallCount == 1)
    }

    @Test("execute throws DiscoveryError when content fetch fails")
    func executeThrowsDiscoveryErrorOnContentFetchFailure() async throws {
        let articleEntry = SmallWebArticleEntry(
            title: "Test",
            articleUrl: URL(string: "https://example.com")!,
            htmlUrl: nil
        )
        mockSourceRepository.randomArticleToReturn = articleEntry
        mockMetadataRepository.shouldThrowOnFetchContent = true

        await #expect(throws: DiscoveryError.self) {
            try await useCase.execute()
        }
    }

    @Test("execute throws when source repository fails")
    func executeThrowsWhenSourceFails() async throws {
        mockSourceRepository.shouldThrowOnRandom = true

        await #expect(throws: SmallWebError.self) {
            try await useCase.execute()
        }
    }

    @Test("execute calls callback with article URL")
    func executeCallsCallbackWithURL() async throws {
        let articleEntry = SmallWebArticleEntry(
            title: "Test",
            articleUrl: URL(string: "https://example.com/callback")!,
            htmlUrl: nil
        )
        mockSourceRepository.randomArticleToReturn = articleEntry

        var callbackURL: URL?
        _ = try await useCase.execute { url in
            callbackURL = url
        }

        #expect(callbackURL == URL(string: "https://example.com/callback")!)
    }

    @Test("execute sets feedTitle from domain")
    func executeSetsFeedTitleFromDomain() async throws {
        let articleEntry = SmallWebArticleEntry(
            title: "Test",
            articleUrl: URL(string: "https://blog.example.com/article")!,
            htmlUrl: nil
        )
        mockSourceRepository.randomArticleToReturn = articleEntry

        let result = try await useCase.execute()

        #expect(result.feedTitle == "blog.example.com")
    }
}
