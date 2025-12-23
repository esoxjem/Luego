import Testing
import Foundation
@testable import Luego

@Suite("SyncSharedArticlesUseCase Tests")
@MainActor
struct SyncSharedArticlesUseCaseTests {
    var mockSharedStorageRepository: MockSharedStorageRepository
    var mockArticleRepository: MockArticleRepository
    var mockMetadataRepository: MockMetadataRepository
    var useCase: SyncSharedArticlesUseCase

    init() {
        mockSharedStorageRepository = MockSharedStorageRepository()
        mockArticleRepository = MockArticleRepository()
        mockMetadataRepository = MockMetadataRepository()
        useCase = SyncSharedArticlesUseCase(
            sharedStorageRepository: mockSharedStorageRepository,
            articleRepository: mockArticleRepository,
            metadataRepository: mockMetadataRepository
        )
    }

    @Test("execute returns empty array when no shared URLs")
    func executeReturnsEmptyWhenNoSharedURLs() async throws {
        mockSharedStorageRepository.sharedURLs = []

        let result = try await useCase.execute()

        #expect(result.isEmpty)
        #expect(mockSharedStorageRepository.getSharedURLsCallCount == 1)
    }

    @Test("execute processes each shared URL")
    func executeProcessesEachSharedURL() async throws {
        mockSharedStorageRepository.sharedURLs = [
            URL(string: "https://example.com/1")!,
            URL(string: "https://example.com/2")!
        ]

        let result = try await useCase.execute()

        #expect(result.count == 2)
        #expect(mockMetadataRepository.validateURLCallCount == 2)
        #expect(mockMetadataRepository.fetchMetadataCallCount == 2)
        #expect(mockArticleRepository.saveCallCount == 2)
    }

    @Test("execute clears shared URLs after processing")
    func executeClearsSharedURLsAfterProcessing() async throws {
        mockSharedStorageRepository.sharedURLs = [URL(string: "https://example.com")!]

        _ = try await useCase.execute()

        #expect(mockSharedStorageRepository.clearSharedURLsCallCount == 1)
    }

    @Test("execute continues processing when one URL validation fails")
    func executeContinuesOnValidationFailure() async throws {
        mockSharedStorageRepository.sharedURLs = [
            URL(string: "https://example.com/1")!,
            URL(string: "https://example.com/2")!
        ]
        mockMetadataRepository.shouldThrowOnValidate = false

        _ = try await useCase.execute()

        #expect(mockSharedStorageRepository.clearSharedURLsCallCount == 1)
    }

    @Test("execute clears shared URLs even when all fail")
    func executeClearsEvenWhenAllFail() async throws {
        mockSharedStorageRepository.sharedURLs = [URL(string: "https://example.com")!]
        mockMetadataRepository.shouldThrowOnValidate = true

        let result = try await useCase.execute()

        #expect(result.isEmpty)
        #expect(mockSharedStorageRepository.clearSharedURLsCallCount == 1)
    }

    @Test("execute does not call clear when no shared URLs")
    func executeDoesNotClearWhenNoURLs() async throws {
        mockSharedStorageRepository.sharedURLs = []

        _ = try await useCase.execute()

        #expect(mockSharedStorageRepository.clearSharedURLsCallCount == 0)
    }

    @Test("execute saves articles with correct metadata")
    func executeSavesWithCorrectMetadata() async throws {
        let url = URL(string: "https://example.com")!
        mockSharedStorageRepository.sharedURLs = [url]
        mockMetadataRepository.metadataToReturn = ArticleMetadata(
            title: "Synced Article",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            description: "Description",
            publishedDate: Date()
        )

        let result = try await useCase.execute()

        #expect(result.count == 1)
        #expect(mockArticleRepository.lastSavedArticle?.title == "Synced Article")
    }
}
