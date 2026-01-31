import Testing
import Foundation
@testable import Luego

@Suite("ReaderViewModel Tests")
@MainActor
struct ReaderViewModelTests {
    var mockReaderService: MockReaderService

    init() {
        mockReaderService = MockReaderService()
    }

    func createViewModel(article: Article) -> ReaderViewModel {
        ReaderViewModel(
            article: article,
            readerService: mockReaderService
        )
    }

    @Test("init sets articleContent from article.content")
    func initSetsArticleContent() {
        let article = ArticleFixtures.createArticle(content: "Existing content")

        let viewModel = createViewModel(article: article)

        #expect(viewModel.articleContent == "Existing content")
    }

    @Test("init sets isLoading true when content is nil")
    func initSetsLoadingTrueWhenNoContent() {
        let article = ArticleFixtures.createArticle(content: nil)

        let viewModel = createViewModel(article: article)

        #expect(viewModel.isLoading == true)
    }

    @Test("init sets isLoading false when content exists")
    func initSetsLoadingFalseWhenContentExists() {
        let article = ArticleFixtures.createArticle(content: "Content")

        let viewModel = createViewModel(article: article)

        #expect(viewModel.isLoading == false)
    }

    @Test("loadContent does nothing when content exists")
    func loadContentDoesNothingWhenExists() async {
        let article = ArticleFixtures.createArticle(content: "Existing")
        let viewModel = createViewModel(article: article)

        await viewModel.loadContent()

        #expect(mockReaderService.fetchContentCallCount == 0)
    }

    @Test("loadContent fetches content when content is nil")
    func loadContentFetchesWhenNil() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)

        await viewModel.loadContent()

        #expect(mockReaderService.fetchContentCallCount == 1)
        #expect(mockReaderService.lastForceRefresh == false)
    }

    @Test("loadContent sets articleContent after fetch")
    func loadContentSetsContentAfterFetch() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)
        let returnArticle = ArticleFixtures.createArticle(content: "Fetched content")
        mockReaderService.articleToReturn = returnArticle

        await viewModel.loadContent()

        #expect(viewModel.articleContent == "Fetched content")
    }

    @Test("loadContent sets isLoading false after success")
    func loadContentSetsLoadingFalseAfterSuccess() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)

        await viewModel.loadContent()

        #expect(viewModel.isLoading == false)
    }

    @Test("loadContent sets errorMessage on failure")
    func loadContentSetsErrorOnFailure() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)
        mockReaderService.shouldThrowOnFetchContent = true

        await viewModel.loadContent()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("refreshContent fetches with forceRefresh true")
    func refreshContentFetchesWithForceRefresh() async {
        let article = ArticleFixtures.createArticle(content: "Old content")
        let viewModel = createViewModel(article: article)

        await viewModel.refreshContent()

        #expect(mockReaderService.fetchContentCallCount == 1)
        #expect(mockReaderService.lastForceRefresh == true)
    }

    @Test("refreshContent updates content after fetch")
    func refreshContentUpdatesContent() async {
        let article = ArticleFixtures.createArticle(content: "Old content")
        let viewModel = createViewModel(article: article)
        let returnArticle = ArticleFixtures.createArticle(content: "New content")
        mockReaderService.articleToReturn = returnArticle

        await viewModel.refreshContent()

        #expect(viewModel.articleContent == "New content")
    }

    @Test("updateReadPosition clamps position below zero")
    func updateReadPositionClampsBelowZero() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(-0.5)

        #expect(mockReaderService.lastUpdatedPosition == 0.0)
        #expect(viewModel.article.readPosition == 0.0)
    }

    @Test("updateReadPosition clamps position above one")
    func updateReadPositionClampsAboveOne() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(1.5)

        #expect(mockReaderService.lastUpdatedPosition == 1.0)
        #expect(viewModel.article.readPosition == 1.0)
    }

    @Test("updateReadPosition calls service with clamped value")
    func updateReadPositionCallsService() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(0.75)

        #expect(mockReaderService.updateReadPositionCallCount == 1)
        #expect(mockReaderService.lastUpdatedArticleId == article.id)
        #expect(mockReaderService.lastUpdatedPosition == 0.75)
    }

    @Test("updateReadPosition sets error on failure")
    func updateReadPositionSetsErrorOnFailure() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)
        mockReaderService.shouldThrowOnUpdateReadPosition = true

        await viewModel.updateReadPosition(0.5)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("updateReadPosition updates article.readPosition locally")
    func updateReadPositionUpdatesLocally() async {
        let article = ArticleFixtures.createArticle(readPosition: 0.0)
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(0.8)

        #expect(viewModel.article.readPosition == 0.8)
    }

    @Test("loadContent handles CancellationError gracefully without setting errorMessage")
    func loadContentHandlesCancellationGracefully() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)
        mockReaderService.shouldThrowCancellationError = true

        await viewModel.loadContent()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }
}
