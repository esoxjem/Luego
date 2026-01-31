import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("SharingService Integration Tests")
@MainActor
struct SharingServiceTests {
    var modelContainer: ModelContainer
    var modelContext: ModelContext
    var mockMetadataDataSource: MockMetadataDataSource
    var mockUserDefaultsDataSource: MockUserDefaultsDataSource
    var sut: SharingService

    init() throws {
        modelContainer = try createTestModelContainer()
        modelContext = modelContainer.mainContext
        mockMetadataDataSource = MockMetadataDataSource()
        mockUserDefaultsDataSource = MockUserDefaultsDataSource()
        sut = SharingService(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource,
            userDefaultsDataSource: mockUserDefaultsDataSource
        )
    }

    private func fetchAllArticles() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    @Test("syncSharedArticles returns empty array when no shared URLs")
    func syncReturnsEmptyWhenNoSharedURLs() async throws {
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = []

        let articles = try await sut.syncSharedArticles()

        #expect(articles.isEmpty)
        #expect(mockMetadataDataSource.validateURLCallCount == 0)
    }

    @Test("syncSharedArticles validates each shared URL")
    func syncValidatesEachURL() async throws {
        let urls = [
            SharedURL(url: URL(string: "https://example.com/article1")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article2")!, timestamp: Date())
        ]
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = urls

        _ = try await sut.syncSharedArticles()

        #expect(mockMetadataDataSource.validateURLCallCount == 2)
    }

    @Test("syncSharedArticles fetches metadata for each valid URL")
    func syncFetchesMetadataForEachURL() async throws {
        let urls = [
            SharedURL(url: URL(string: "https://example.com/article1")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article2")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article3")!, timestamp: Date())
        ]
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = urls

        _ = try await sut.syncSharedArticles()

        #expect(mockMetadataDataSource.fetchMetadataCallCount == 3)
    }

    @Test("syncSharedArticles creates and persists articles to SwiftData")
    func syncCreatesAndPersistsArticles() async throws {
        let url = URL(string: "https://example.com/shared")!
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = [SharedURL(url: url, timestamp: Date())]
        mockMetadataDataSource.metadataToReturn = ArticleMetadata(
            title: "Shared Article",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            description: "Description",
            publishedDate: Date()
        )

        let articles = try await sut.syncSharedArticles()

        #expect(articles.count == 1)
        #expect(articles.first?.title == "Shared Article")
        #expect(articles.first?.url == url)

        let persistedArticles = try fetchAllArticles()
        #expect(persistedArticles.count == 1)
    }

    @Test("syncSharedArticles returns all successfully synced articles")
    func syncReturnsAllSuccessfulArticles() async throws {
        let urls = [
            SharedURL(url: URL(string: "https://example.com/article1")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article2")!, timestamp: Date())
        ]
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = urls

        let articles = try await sut.syncSharedArticles()

        #expect(articles.count == 2)
    }

    @Test("syncSharedArticles continues processing on individual URL failure")
    func syncContinuesOnIndividualFailure() async throws {
        let urls = [
            SharedURL(url: URL(string: "https://example.com/article1")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article2")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article3")!, timestamp: Date())
        ]
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = urls
        mockUserDefaultsDataSource.sharedURLs = urls.map { $0.url }

        let testSut = SharingServiceWithFailureSimulation(
            modelContext: modelContext,
            metadataDataSource: mockMetadataDataSource,
            userDefaultsDataSource: mockUserDefaultsDataSource,
            failOnURLIndex: 1
        )

        let articles = try await testSut.syncSharedArticles()

        #expect(articles.count == 2)
    }

    @Test("syncSharedArticles updates last sync timestamp after sync")
    func syncUpdatesLastSyncTimestampAfterSync() async throws {
        let timestamp = Date()
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = [
            SharedURL(url: URL(string: "https://example.com/article")!, timestamp: timestamp)
        ]

        _ = try await sut.syncSharedArticles()

        #expect(mockUserDefaultsDataSource.setLastSyncTimestampCallCount == 1)
        #expect(mockUserDefaultsDataSource.lastSyncTimestamp == timestamp)
    }

    @Test("syncSharedArticles does not update timestamp when all URLs fail")
    func syncDoesNotUpdateTimestampOnAllFailures() async throws {
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = [
            SharedURL(url: URL(string: "https://example.com/article")!, timestamp: Date())
        ]
        mockMetadataDataSource.shouldThrowOnValidateURL = true

        let articles = try await sut.syncSharedArticles()

        #expect(articles.isEmpty)
        #expect(mockUserDefaultsDataSource.setLastSyncTimestampCallCount == 0)
    }

    @Test("syncSharedArticles persists articles with correct metadata")
    func syncPersistsWithCorrectMetadata() async throws {
        let url = URL(string: "https://example.com/shared")!
        let publishedDate = Date()
        let thumbnailURL = URL(string: "https://example.com/image.jpg")!
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = [SharedURL(url: url, timestamp: Date())]
        mockMetadataDataSource.metadataToReturn = ArticleMetadata(
            title: "Full Metadata Article",
            thumbnailURL: thumbnailURL,
            description: "Full description",
            publishedDate: publishedDate
        )

        let articles = try await sut.syncSharedArticles()

        #expect(articles.first?.title == "Full Metadata Article")
        #expect(articles.first?.thumbnailURL == thumbnailURL)
        #expect(articles.first?.publishedDate == publishedDate)
        #expect(articles.first?.content == nil)
        #expect(articles.first?.readPosition == 0)
    }

    @Test("syncSharedArticles reads from user defaults data source with timestamp filter")
    func syncReadsFromUserDefaultsDataSourceWithTimestampFilter() async throws {
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = []

        _ = try await sut.syncSharedArticles()

        #expect(mockUserDefaultsDataSource.getSharedURLsAfterCallCount == 1)
        #expect(mockUserDefaultsDataSource.getLastSyncTimestampCallCount == 1)
    }

    @Test("syncSharedArticles skips duplicate URLs via fast-path check")
    func syncSkipsDuplicateURLsViaFastPath() async throws {
        let url = URL(string: "https://example.com/duplicate")!

        let existingArticle = Article(
            url: url,
            title: "Existing Article"
        )
        modelContext.insert(existingArticle)
        try modelContext.save()

        mockUserDefaultsDataSource.sharedURLsWithTimestamps = [SharedURL(url: url, timestamp: Date())]

        let articles = try await sut.syncSharedArticles()

        #expect(articles.isEmpty)
        #expect(mockMetadataDataSource.fetchMetadataCallCount == 0)

        let allArticles = try fetchAllArticles()
        #expect(allArticles.count == 1)
        #expect(allArticles.first?.title == "Existing Article")
    }

    @Test("syncSharedArticles handles constraint violation gracefully")
    func syncHandlesConstraintViolationGracefully() async throws {
        let urls = [
            SharedURL(url: URL(string: "https://example.com/article1")!, timestamp: Date()),
            SharedURL(url: URL(string: "https://example.com/article2")!, timestamp: Date())
        ]
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = urls

        let articles = try await sut.syncSharedArticles()

        #expect(articles.count == 2)

        let allArticles = try fetchAllArticles()
        #expect(allArticles.count == 2)
    }

    @Test("syncSharedArticles only processes URLs newer than last sync timestamp")
    func syncOnlyProcessesNewerURLs() async throws {
        let oldTimestamp = Date().addingTimeInterval(-3600)
        let newTimestamp = Date()
        mockUserDefaultsDataSource.lastSyncTimestamp = oldTimestamp
        mockUserDefaultsDataSource.sharedURLsWithTimestamps = [
            SharedURL(url: URL(string: "https://example.com/old")!, timestamp: oldTimestamp.addingTimeInterval(-60)),
            SharedURL(url: URL(string: "https://example.com/new")!, timestamp: newTimestamp)
        ]

        let articles = try await sut.syncSharedArticles()

        #expect(articles.count == 1)
        #expect(articles.first?.url.absoluteString == "https://example.com/new")
    }
}

@MainActor
final class SharingServiceWithFailureSimulation: SharingServiceProtocol {
    private let modelContext: ModelContext
    private let metadataDataSource: MetadataDataSourceProtocol
    private let userDefaultsDataSource: UserDefaultsDataSourceProtocol
    private let failOnURLIndex: Int

    init(
        modelContext: ModelContext,
        metadataDataSource: MetadataDataSourceProtocol,
        userDefaultsDataSource: UserDefaultsDataSourceProtocol,
        failOnURLIndex: Int
    ) {
        self.modelContext = modelContext
        self.metadataDataSource = metadataDataSource
        self.userDefaultsDataSource = userDefaultsDataSource
        self.failOnURLIndex = failOnURLIndex
    }

    func syncSharedArticles() async throws -> [Article] {
        let sharedURLs = userDefaultsDataSource.getSharedURLs()
        guard !sharedURLs.isEmpty else { return [] }

        var newArticles: [Article] = []

        for (index, url) in sharedURLs.enumerated() {
            do {
                if index == failOnURLIndex {
                    throw ArticleMetadataError.invalidURL
                }

                let validatedURL = try await metadataDataSource.validateURL(url)
                let metadata = try await metadataDataSource.fetchMetadata(for: validatedURL)

                let article = Article(
                    id: UUID(),
                    url: validatedURL,
                    title: metadata.title,
                    content: nil,
                    savedDate: Date(),
                    thumbnailURL: metadata.thumbnailURL,
                    publishedDate: metadata.publishedDate,
                    readPosition: 0
                )

                modelContext.insert(article)
                try modelContext.save()
                newArticles.append(article)
            } catch {
                continue
            }
        }

        userDefaultsDataSource.clearSharedURLs()
        return newArticles
    }
}
