import Testing
import Foundation
@testable import Luego

@Suite("ArticleListViewModel Tests")
@MainActor
struct ArticleListViewModelTests {
    var mockArticleService: MockArticleService
    var mockSharingService: MockSharingService
    var viewModel: ArticleListViewModel

    init() {
        mockArticleService = MockArticleService()
        mockSharingService = MockSharingService()
        viewModel = ArticleListViewModel(
            articleService: mockArticleService,
            sharingService: mockSharingService
        )
    }

    @Test("addArticle sets error for invalid URL")
    func addArticleSetsErrorForInvalidURL() async {
        await viewModel.addArticle(from: "http://[::1", existingArticles: [])

        #expect(viewModel.errorMessage == "Please enter a valid URL")
        #expect(mockArticleService.addArticleCallCount == 0)
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
        #expect(mockArticleService.addArticleCallCount == 0)
    }

    @Test("addArticle trims whitespace from URL")
    func addArticleTrimsWhitespace() async {
        await viewModel.addArticle(from: "  https://example.com  ", existingArticles: [])

        #expect(mockArticleService.lastAddedURL == URL(string: "https://example.com")!)
    }

    @Test("addArticle calls service for valid new URL")
    func addArticleCallsService() async {
        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(mockArticleService.addArticleCallCount == 1)
    }

    @Test("addArticle clears error before adding")
    func addArticleClearsErrorFirst() async {
        viewModel.errorMessage = "Previous error"

        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(viewModel.errorMessage == nil)
    }

    @Test("addArticle sets error on service failure")
    func addArticleSetsErrorOnFailure() async {
        mockArticleService.shouldThrowOnAddArticle = true

        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(viewModel.errorMessage != nil)
    }

    @Test("addArticle sets isLoading false after completion")
    func addArticleSetsLoadingFalseAfter() async {
        await viewModel.addArticle(from: "https://example.com", existingArticles: [])

        #expect(viewModel.isLoading == false)
    }

    @Test("deleteArticle calls service with correct id")
    func deleteArticleCallsService() async {
        let article = ArticleFixtures.createArticle()

        await viewModel.deleteArticle(article)

        #expect(mockArticleService.deleteArticleCallCount == 1)
        #expect(mockArticleService.lastDeletedId == article.id)
    }

    @Test("deleteArticle sets error on failure")
    func deleteArticleSetsErrorOnFailure() async {
        mockArticleService.shouldThrowOnDeleteArticle = true
        let article = ArticleFixtures.createArticle()

        await viewModel.deleteArticle(article)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("toggleFavorite calls service with correct id")
    func toggleFavoriteCallsService() async {
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleFavorite(article)

        #expect(mockArticleService.toggleFavoriteCallCount == 1)
        #expect(mockArticleService.lastToggledFavoriteId == article.id)
    }

    @Test("toggleFavorite sets error on failure")
    func toggleFavoriteSetsErrorOnFailure() async {
        mockArticleService.shouldThrowOnToggleFavorite = true
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleFavorite(article)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("toggleArchive calls service with correct id")
    func toggleArchiveCallsService() async {
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleArchive(article)

        #expect(mockArticleService.toggleArchiveCallCount == 1)
        #expect(mockArticleService.lastToggledArchiveId == article.id)
    }

    @Test("toggleArchive sets error on failure")
    func toggleArchiveSetsErrorOnFailure() async {
        mockArticleService.shouldThrowOnToggleArchive = true
        let article = ArticleFixtures.createArticle()

        await viewModel.toggleArchive(article)

        #expect(viewModel.errorMessage != nil)
    }

    @Test("syncSharedArticles calls service")
    func syncSharedArticlesCallsService() async {
        await viewModel.syncSharedArticles()

        #expect(mockSharingService.syncSharedArticlesCallCount == 1)
    }

    @Test("syncSharedArticles sets error on failure")
    func syncSharedArticlesSetsErrorOnFailure() async {
        mockSharingService.shouldThrowOnSyncSharedArticles = true

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
