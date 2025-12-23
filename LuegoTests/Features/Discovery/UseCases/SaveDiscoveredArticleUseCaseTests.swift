import Testing
import Foundation
@testable import Luego

@Suite("SaveDiscoveredArticleUseCase Tests")
@MainActor
struct SaveDiscoveredArticleUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var useCase: SaveDiscoveredArticleUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        useCase = SaveDiscoveredArticleUseCase(articleRepository: mockArticleRepository)
    }

    @Test("execute converts ephemeral article to article and saves")
    func executeConvertsAndSaves() async throws {
        let ephemeral = EphemeralArticleFixtures.createEphemeralArticle(
            url: URL(string: "https://example.com/discovered")!,
            title: "Discovered Title",
            content: "Discovered content"
        )

        let result = try await useCase.execute(ephemeralArticle: ephemeral)

        #expect(mockArticleRepository.saveCallCount == 1)
        #expect(result.url == ephemeral.url)
        #expect(result.title == "Discovered Title")
        #expect(result.content == "Discovered content")
    }

    @Test("execute preserves all ephemeral article properties")
    func executePreservesAllProperties() async throws {
        let thumbnailURL = URL(string: "https://example.com/thumb.jpg")!
        let publishedDate = Date().addingTimeInterval(-86400)
        let ephemeral = EphemeralArticleFixtures.createEphemeralArticle(
            url: URL(string: "https://example.com")!,
            title: "Title",
            content: "Content",
            thumbnailURL: thumbnailURL,
            publishedDate: publishedDate
        )

        let result = try await useCase.execute(ephemeralArticle: ephemeral)

        #expect(result.thumbnailURL == thumbnailURL)
        #expect(result.publishedDate == publishedDate)
    }

    @Test("execute throws when save fails")
    func executeThrowsOnSaveFailure() async throws {
        mockArticleRepository.shouldThrowOnSave = true
        let ephemeral = EphemeralArticleFixtures.createEphemeralArticle()

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(ephemeralArticle: ephemeral)
        }
    }

    @Test("execute creates article with nil thumbnailURL when not provided")
    func executeHandlesNilThumbnail() async throws {
        let ephemeral = EphemeralArticleFixtures.createEphemeralArticle(thumbnailURL: nil)

        let result = try await useCase.execute(ephemeralArticle: ephemeral)

        #expect(result.thumbnailURL == nil)
    }

    @Test("execute creates article with nil publishedDate when not provided")
    func executeHandlesNilPublishedDate() async throws {
        let ephemeral = EphemeralArticleFixtures.createEphemeralArticle(publishedDate: nil)

        let result = try await useCase.execute(ephemeralArticle: ephemeral)

        #expect(result.publishedDate == nil)
    }
}
