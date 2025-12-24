import Testing
import Foundation
@testable import Luego

@Suite("DiscoveryViewModel Tests")
@MainActor
struct DiscoveryViewModelTests {
    var mockDiscoveryService: MockDiscoveryService
    var mockArticleService: MockArticleService
    var mockPreferencesDataSource: MockDiscoveryPreferencesDataSource
    var viewModel: DiscoveryViewModel

    init() {
        mockDiscoveryService = MockDiscoveryService()
        mockArticleService = MockArticleService()
        mockPreferencesDataSource = MockDiscoveryPreferencesDataSource()

        viewModel = DiscoveryViewModel(
            discoveryService: mockDiscoveryService,
            articleService: mockArticleService,
            preferencesDataSource: mockPreferencesDataSource
        )
    }

    @Test("init sets selectedSource from preferences")
    func initSetsSelectedSource() {
        mockPreferencesDataSource.selectedSource = .blogroll
        let vm = DiscoveryViewModel(
            discoveryService: mockDiscoveryService,
            articleService: mockArticleService,
            preferencesDataSource: mockPreferencesDataSource
        )

        #expect(vm.selectedSource == .blogroll)
    }

    @Test("fetchRandomArticle sets isLoading to true during fetch")
    func fetchRandomArticleSetsLoading() async {
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.isLoading == false)
    }

    @Test("fetchRandomArticle clears previous state")
    func fetchRandomArticleClearsState() async {
        viewModel.ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle()
        viewModel.errorMessage = "Old error"
        viewModel.isSaved = true
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.errorMessage == nil)
    }

    @Test("fetchRandomArticle sets ephemeralArticle on success")
    func fetchRandomArticleSetsArticle() async {
        let expectedArticle = EphemeralArticleFixtures.createEphemeralArticle(title: "Discovered")
        mockDiscoveryService.ephemeralArticleToReturn = expectedArticle

        await viewModel.fetchRandomArticle()

        #expect(viewModel.ephemeralArticle?.title == "Discovered")
    }

    @Test("fetchRandomArticle calls prepareForFetch")
    func fetchRandomArticleCallsPrepare() async {
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(mockDiscoveryService.prepareForFetchCallCount == 1)
    }

    @Test("fetchRandomArticle sets activeSource from prepareForFetch")
    func fetchRandomArticleSetsActiveSource() async {
        mockDiscoveryService.sourceToReturnForPrepare = .blogroll
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.activeSource == .blogroll)
    }

    @Test("fetchRandomArticle checks if article already saved")
    func fetchRandomArticleChecksIfSaved() async {
        let url = URL(string: "https://example.com/saved")!
        let savedArticle = ArticleFixtures.createArticle(url: url)
        mockArticleService.articlesToReturn = [savedArticle]
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle(url: url)

        await viewModel.fetchRandomArticle()

        #expect(viewModel.isSaved == true)
    }

    @Test("fetchRandomArticle sets isSaved false when not saved")
    func fetchRandomArticleSetsNotSaved() async {
        mockArticleService.articlesToReturn = []
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.isSaved == false)
    }

    @Test("saveToReadingList calls save service")
    func saveToReadingListCallsService() async {
        let article = EphemeralArticleFixtures.createEphemeralArticle()
        viewModel.ephemeralArticle = article

        await viewModel.saveToReadingList()

        #expect(mockArticleService.saveEphemeralArticleCallCount == 1)
        #expect(mockArticleService.lastSavedEphemeralArticle?.url == article.url)
    }

    @Test("saveToReadingList sets isSaved to true on success")
    func saveToReadingListSetsSaved() async {
        viewModel.ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.saveToReadingList()

        #expect(viewModel.isSaved == true)
    }

    @Test("saveToReadingList does nothing when no ephemeralArticle")
    func saveToReadingListDoesNothingWhenNoArticle() async {
        viewModel.ephemeralArticle = nil

        await viewModel.saveToReadingList()

        #expect(mockArticleService.saveEphemeralArticleCallCount == 0)
    }

    @Test("saveToReadingList sets error on failure")
    func saveToReadingListSetsErrorOnFailure() async {
        viewModel.ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle()
        mockArticleService.shouldThrowOnSaveEphemeralArticle = true

        await viewModel.saveToReadingList()

        #expect(viewModel.errorMessage == "Failed to save article")
    }

    @Test("loadAnotherArticle calls fetchRandomArticle")
    func loadAnotherArticleCallsFetch() async {
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.loadAnotherArticle()

        #expect(mockDiscoveryService.prepareForFetchCallCount >= 1)
    }

    @Test("currentLoadingText returns active source loading text when active")
    func currentLoadingTextUsesActiveSource() async {
        mockDiscoveryService.sourceToReturnForPrepare = .blogroll
        mockDiscoveryService.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()
        await viewModel.fetchRandomArticle()

        let text = viewModel.currentLoadingText

        #expect(text == DiscoverySource.blogroll.loadingText)
    }
}
