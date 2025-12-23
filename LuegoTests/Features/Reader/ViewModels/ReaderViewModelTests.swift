import Testing
import Foundation
@testable import Luego

@Suite("ReaderViewModel Tests")
@MainActor
struct ReaderViewModelTests {
    var mockFetchContentUseCase: MockFetchArticleContentUseCase
    var mockUpdateReadPositionUseCase: MockUpdateArticleReadPositionUseCase

    init() {
        mockFetchContentUseCase = MockFetchArticleContentUseCase()
        mockUpdateReadPositionUseCase = MockUpdateArticleReadPositionUseCase()
    }

    func createViewModel(article: Article) -> ReaderViewModel {
        ReaderViewModel(
            article: article,
            fetchContentUseCase: mockFetchContentUseCase,
            updateReadPositionUseCase: mockUpdateReadPositionUseCase
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

        #expect(mockFetchContentUseCase.executeCallCount == 0)
    }

    @Test("loadContent fetches content when content is nil")
    func loadContentFetchesWhenNil() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)

        await viewModel.loadContent()

        #expect(mockFetchContentUseCase.executeCallCount == 1)
        #expect(mockFetchContentUseCase.lastForceRefresh == false)
    }

    @Test("loadContent sets articleContent after fetch")
    func loadContentSetsContentAfterFetch() async {
        let article = ArticleFixtures.createArticle(content: nil)
        let viewModel = createViewModel(article: article)
        mockFetchContentUseCase.contentToSet = "Fetched content"

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
        mockFetchContentUseCase.shouldThrow = true

        await viewModel.loadContent()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("refreshContent fetches with forceRefresh true")
    func refreshContentFetchesWithForceRefresh() async {
        let article = ArticleFixtures.createArticle(content: "Old content")
        let viewModel = createViewModel(article: article)

        await viewModel.refreshContent()

        #expect(mockFetchContentUseCase.executeCallCount == 1)
        #expect(mockFetchContentUseCase.lastForceRefresh == true)
    }

    @Test("refreshContent updates content after fetch")
    func refreshContentUpdatesContent() async {
        let article = ArticleFixtures.createArticle(content: "Old content")
        let viewModel = createViewModel(article: article)
        mockFetchContentUseCase.contentToSet = "New content"

        await viewModel.refreshContent()

        #expect(viewModel.articleContent == "New content")
    }

    @Test("updateReadPosition clamps position below zero")
    func updateReadPositionClampsBelowZero() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(-0.5)

        #expect(mockUpdateReadPositionUseCase.lastPosition == 0.0)
        #expect(viewModel.article.readPosition == 0.0)
    }

    @Test("updateReadPosition clamps position above one")
    func updateReadPositionClampsAboveOne() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(1.5)

        #expect(mockUpdateReadPositionUseCase.lastPosition == 1.0)
        #expect(viewModel.article.readPosition == 1.0)
    }

    @Test("updateReadPosition calls use case with clamped value")
    func updateReadPositionCallsUseCase() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)

        await viewModel.updateReadPosition(0.75)

        #expect(mockUpdateReadPositionUseCase.executeCallCount == 1)
        #expect(mockUpdateReadPositionUseCase.lastArticleId == article.id)
        #expect(mockUpdateReadPositionUseCase.lastPosition == 0.75)
    }

    @Test("updateReadPosition sets error on failure")
    func updateReadPositionSetsErrorOnFailure() async {
        let article = ArticleFixtures.createArticle()
        let viewModel = createViewModel(article: article)
        mockUpdateReadPositionUseCase.shouldThrow = true

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
}
