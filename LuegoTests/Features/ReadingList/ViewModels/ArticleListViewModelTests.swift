import Testing
import Foundation
@testable import Luego

@Suite("ArticleListViewModel Tests")
@MainActor
struct ArticleListViewModelTests {
    var mockGetArticlesUseCase: MockGetArticlesUseCase
    var mockAddArticleUseCase: MockAddArticleUseCase
    var mockDeleteArticleUseCase: MockDeleteArticleUseCase
    var mockSyncSharedArticlesUseCase: MockSyncSharedArticlesUseCase
    var mockToggleFavoriteUseCase: MockToggleFavoriteUseCase
    var mockToggleArchiveUseCase: MockToggleArchiveUseCase
    var viewModel: ArticleListViewModel

    init() {
        mockGetArticlesUseCase = MockGetArticlesUseCase()
        mockAddArticleUseCase = MockAddArticleUseCase()
        mockDeleteArticleUseCase = MockDeleteArticleUseCase()
        mockSyncSharedArticlesUseCase = MockSyncSharedArticlesUseCase()
        mockToggleFavoriteUseCase = MockToggleFavoriteUseCase()
        mockToggleArchiveUseCase = MockToggleArchiveUseCase()
        viewModel = ArticleListViewModel(
            getArticlesUseCase: mockGetArticlesUseCase,
            addArticleUseCase: mockAddArticleUseCase,
            deleteArticleUseCase: mockDeleteArticleUseCase,
            syncSharedArticlesUseCase: mockSyncSharedArticlesUseCase,
            toggleFavoriteUseCase: mockToggleFavoriteUseCase,
            toggleArchiveUseCase: mockToggleArchiveUseCase
        )
    }

    @Test("addArticle sets error for invalid URL")
    func addArticleSetsErrorForInvalidURL() async {
        await viewModel.addArticle(from: "http://[::1", existingArticles: [])

        #expect(viewModel.errorMessage == "Please enter a valid URL")
        #expect(mockAddArticleUseCase.executeCallCount == 0)
    }

    @Test("addArticle sets error for empty string")
    func addArticleSetsErrorForEmptyString() async {
        await viewModel.addArticle(from: "", existingArticles: [])

        #expect(viewModel.errorMessage == "Please enter a valid URL")
    }

    @Test("addArticle sets error for whitespace only")
    func addArticleSetsErrorForWhitespace() async {
        await viewModel.addArticle(from: "   ", existingArticles: [])

        #expect(viewModel.errorMessage == "Please enter a valid URL")
    }

    @Test("addArticle sets error for duplicate URL")
    func addArticleSetsErrorForDuplicate() async {
        let existingArticle = ArticleFixtures.createArticle(
            url: URL(string: "https://example.com")!
        )

        await viewModel.addArticle(from: "https://example.com", existingArticles: [existingArticle])

        #expect(viewModel.errorMessage == "This article has already been saved")
        #expect(mockAddArticleUseCase.executeCallCount == 0)
    }

    @Test("addArticle trims whitespace from URL")
    func addArticleTrimsWhitespace() async {
        await viewModel.addArticle(from: "  https://example.com  ", existingArticles: [])

        #expect(mockAddArticleUseCase.lastURL == URL(string: "https://example.com")!)
    }

    @Test("addArticle calls use case for valid new URL")
    func addArticleCallsUseCase() async {
        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(mockAddArticleUseCase.executeCallCount == 1)
    }

    @Test("addArticle clears error before adding")
    func addArticleClearsErrorFirst() async {
        viewModel.errorMessage = "Previous error"

        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(viewModel.errorMessage == nil)
    }

    @Test("addArticle sets error on use case failure")
    func addArticleSetsErrorOnFailure() async {
        mockAddArticleUseCase.shouldThrow = true
        mockAddArticleUseCase.errorToThrow = ArticleMetadataError.networkError(NSError(domain: "Test", code: 1))

        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(viewModel.errorMessage != nil)
    }

    @Test("addArticle sets isLoading false after completion")
    func addArticleSetsLoadingFalseAfter() async {
        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(viewModel.isLoading == false)
    }

    @Test("deleteArticle calls use case with correct id")
    func deleteArticleCallsUseCase() async {
        let article = ArticleFixtures.createArticle()

        await viewModel.deleteArticle(article)

        #expect(mockDeleteArticleUseCase.executeCallCount == 1)
        #expect(mockDeleteArticleUseCase.lastDeletedId == article.id)
    }

    @Test("deleteArticle sets error on failure")
    func deleteArticleSetsErrorOnFailure() async {
        mockDeleteArticleUseCase.shouldThrow = true
        let article = ArticleFixtures.createArticle()

        await viewModel.deleteArticle(article)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("toggleFavorite calls use case with correct id")
    func toggleFavoriteCallsUseCase() async {
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleFavorite(article)

        #expect(mockToggleFavoriteUseCase.executeCallCount == 1)
        #expect(mockToggleFavoriteUseCase.lastToggledId == article.id)
    }

    @Test("toggleFavorite sets error on failure")
    func toggleFavoriteSetsErrorOnFailure() async {
        mockToggleFavoriteUseCase.shouldThrow = true
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleFavorite(article)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("toggleArchive calls use case with correct id")
    func toggleArchiveCallsUseCase() async {
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleArchive(article)

        #expect(mockToggleArchiveUseCase.executeCallCount == 1)
        #expect(mockToggleArchiveUseCase.lastToggledId == article.id)
    }

    @Test("toggleArchive sets error on failure")
    func toggleArchiveSetsErrorOnFailure() async {
        mockToggleArchiveUseCase.shouldThrow = true
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleArchive(article)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("syncSharedArticles calls use case")
    func syncSharedArticlesCallsUseCase() async {
        await viewModel.syncSharedArticles()

        #expect(mockSyncSharedArticlesUseCase.executeCallCount == 1)
    }

    @Test("syncSharedArticles sets error on failure")
    func syncSharedArticlesSetsErrorOnFailure() async {
        mockSyncSharedArticlesUseCase.shouldThrow = true

        await viewModel.syncSharedArticles()

        #expect(viewModel.errorMessage != nil)
    }

    @Test("clearError clears errorMessage")
    func clearErrorClearsMessage() {
        viewModel.errorMessage = "Some error"

        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
    }
}
