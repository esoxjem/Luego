import Testing
import Foundation
@testable import Luego

@Suite("AddArticleUseCase Tests")
@MainActor
struct AddArticleUseCaseTests {
    var mockArticleRepository: MockArticleRepository
    var mockMetadataRepository: MockMetadataRepository
    var useCase: AddArticleUseCase

    init() {
        mockArticleRepository = MockArticleRepository()
        mockMetadataRepository = MockMetadataRepository()
        useCase = AddArticleUseCase(
            articleRepository: mockArticleRepository,
            metadataRepository: mockMetadataRepository
        )
    }

    @Test("execute validates URL first")
    func executeValidatesURLFirst() async throws {
        let url = URL(string: "https://example.com")!

        _ = try await useCase.execute(url: url)

        #expect(mockMetadataRepository.validateURLCallCount == 1)
        #expect(mockMetadataRepository.lastValidatedURL == url)
    }

    @Test("execute fetches metadata after validation")
    func executeFetchesMetadata() async throws {
        let url = URL(string: "https://example.com")!

        _ = try await useCase.execute(url: url)

        #expect(mockMetadataRepository.fetchMetadataCallCount == 1)
    }

    @Test("execute uses validated URL for metadata fetch")
    func executeUsesValidatedURLForMetadata() async throws {
        let originalURL = URL(string: "https://example.com")!
        let validatedURL = URL(string: "https://example.com/validated")!
        mockMetadataRepository.validatedURLToReturn = validatedURL

        _ = try await useCase.execute(url: originalURL)

        #expect(mockMetadataRepository.lastMetadataURL == validatedURL)
    }

    @Test("execute saves article with fetched metadata")
    func executeSavesArticle() async throws {
        let url = URL(string: "https://example.com")!
        mockMetadataRepository.metadataToReturn = ArticleMetadata(
            title: "Custom Title",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            description: "Description",
            publishedDate: Date()
        )

        let article = try await useCase.execute(url: url)

        #expect(mockArticleRepository.saveCallCount == 1)
        #expect(article.title == "Custom Title")
        #expect(article.thumbnailURL == URL(string: "https://example.com/thumb.jpg"))
    }

    @Test("execute creates article with nil content")
    func executeCreatesArticleWithNilContent() async throws {
        let url = URL(string: "https://example.com")!

        let article = try await useCase.execute(url: url)

        #expect(article.content == nil)
    }

    @Test("execute creates article with zero read position")
    func executeCreatesArticleWithZeroReadPosition() async throws {
        let url = URL(string: "https://example.com")!

        let article = try await useCase.execute(url: url)

        #expect(article.readPosition == 0)
    }

    @Test("execute throws when URL validation fails")
    func executeThrowsOnInvalidURL() async throws {
        mockMetadataRepository.shouldThrowOnValidate = true
        let url = URL(string: "https://example.com")!

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(url: url)
        }
    }

    @Test("execute throws when metadata fetch fails")
    func executeThrowsOnMetadataFetchFailure() async throws {
        mockMetadataRepository.shouldThrowOnFetchMetadata = true
        let url = URL(string: "https://example.com")!

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(url: url)
        }
    }

    @Test("execute throws when save fails")
    func executeThrowsOnSaveFailure() async throws {
        mockArticleRepository.shouldThrowOnSave = true
        let url = URL(string: "https://example.com")!

        await #expect(throws: ArticleMetadataError.self) {
            try await useCase.execute(url: url)
        }
    }

    @Test("execute preserves published date from metadata")
    func executePreservesPublishedDate() async throws {
        let url = URL(string: "https://example.com")!
        let publishedDate = Date().addingTimeInterval(-86400)
        mockMetadataRepository.metadataToReturn = ArticleMetadata(
            title: "Title",
            thumbnailURL: nil,
            description: nil,
            publishedDate: publishedDate
        )

        let article = try await useCase.execute(url: url)

        #expect(article.publishedDate == publishedDate)
    }
}
