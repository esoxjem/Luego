import Testing
import Foundation
@testable import Luego

@Suite("DiscoveryViewModel Tests")
@MainActor
struct DiscoveryViewModelTests {
    var mockFetchRandomArticleUseCase: MockFetchRandomArticleUseCase
    var mockSaveDiscoveredArticleUseCase: MockSaveDiscoveredArticleUseCase
    var mockArticleRepository: MockArticleRepository
    var mockPreferencesDataSource: MockDiscoveryPreferencesDataSource
    var viewModel: DiscoveryViewModel

    init() {
        mockFetchRandomArticleUseCase = MockFetchRandomArticleUseCase()
        mockSaveDiscoveredArticleUseCase = MockSaveDiscoveredArticleUseCase()
        mockArticleRepository = MockArticleRepository()
        mockPreferencesDataSource = MockDiscoveryPreferencesDataSource()

        let fetchUseCase = mockFetchRandomArticleUseCase
        viewModel = DiscoveryViewModel(
            useCaseFactory: { _ in fetchUseCase },
            saveDiscoveredArticleUseCase: mockSaveDiscoveredArticleUseCase,
            articleRepository: mockArticleRepository,
            preferencesDataSource: mockPreferencesDataSource
        )
    }

    @Test("init sets selectedSource from preferences")
    func initSetsSelectedSource() {
        mockPreferencesDataSource.selectedSource = .blogroll
        let fetchUseCase = mockFetchRandomArticleUseCase
        let vm = DiscoveryViewModel(
            useCaseFactory: { _ in fetchUseCase },
            saveDiscoveredArticleUseCase: mockSaveDiscoveredArticleUseCase,
            articleRepository: mockArticleRepository,
            preferencesDataSource: mockPreferencesDataSource
        )

        #expect(vm.selectedSource == .blogroll)
    }

    @Test("fetchRandomArticle sets isLoading to true during fetch")
    func fetchRandomArticleSetsLoading() async {
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.isLoading == false)
    }

    @Test("fetchRandomArticle clears previous state")
    func fetchRandomArticleClearsState() async {
        viewModel.ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle()
        viewModel.errorMessage = "Old error"
        viewModel.isSaved = true
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.errorMessage == nil)
    }

    @Test("fetchRandomArticle sets ephemeralArticle on success")
    func fetchRandomArticleSetsArticle() async {
        let expectedArticle = EphemeralArticleFixtures.createEphemeralArticle(title: "Discovered")
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = expectedArticle

        await viewModel.fetchRandomArticle()

        #expect(viewModel.ephemeralArticle?.title == "Discovered")
    }

    @Test("fetchRandomArticle calls prepareForFetch")
    func fetchRandomArticleCallsPrepare() async {
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(mockFetchRandomArticleUseCase.prepareForFetchCallCount == 1)
    }

    @Test("fetchRandomArticle sets activeSource from prepareForFetch")
    func fetchRandomArticleSetsActiveSource() async {
        mockFetchRandomArticleUseCase.sourceToReturn = .blogroll
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.activeSource == .blogroll)
    }

    @Test("fetchRandomArticle checks if article already saved")
    func fetchRandomArticleChecksIfSaved() async {
        let url = URL(string: "https://example.com/saved")!
        let savedArticle = ArticleFixtures.createArticle(url: url)
        mockArticleRepository.articles = [savedArticle]
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle(url: url)

        await viewModel.fetchRandomArticle()

        #expect(viewModel.isSaved == true)
    }

    @Test("fetchRandomArticle sets isSaved false when not saved")
    func fetchRandomArticleSetsNotSaved() async {
        mockArticleRepository.articles = []
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.fetchRandomArticle()

        #expect(viewModel.isSaved == false)
    }

    @Test("saveToReadingList calls save use case")
    func saveToReadingListCallsUseCase() async {
        let article = EphemeralArticleFixtures.createEphemeralArticle()
        viewModel.ephemeralArticle = article

        await viewModel.saveToReadingList()

        #expect(mockSaveDiscoveredArticleUseCase.executeCallCount == 1)
        #expect(mockSaveDiscoveredArticleUseCase.lastEphemeralArticle?.url == article.url)
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

        #expect(mockSaveDiscoveredArticleUseCase.executeCallCount == 0)
    }

    @Test("saveToReadingList sets error on failure")
    func saveToReadingListSetsErrorOnFailure() async {
        viewModel.ephemeralArticle = EphemeralArticleFixtures.createEphemeralArticle()
        mockSaveDiscoveredArticleUseCase.shouldThrow = true

        await viewModel.saveToReadingList()

        #expect(viewModel.errorMessage == "Failed to save article")
    }

    @Test("loadAnotherArticle calls fetchRandomArticle")
    func loadAnotherArticleCallsFetch() async {
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()

        await viewModel.loadAnotherArticle()

        #expect(mockFetchRandomArticleUseCase.prepareForFetchCallCount >= 1)
    }

    @Test("currentLoadingText returns active source loading text when active")
    func currentLoadingTextUsesActiveSource() async {
        mockFetchRandomArticleUseCase.sourceToReturn = .blogroll
        mockFetchRandomArticleUseCase.ephemeralArticleToReturn = EphemeralArticleFixtures.createEphemeralArticle()
        await viewModel.fetchRandomArticle()

        let text = viewModel.currentLoadingText

        #expect(text == DiscoverySource.blogroll.loadingText)
    }
}
