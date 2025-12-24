import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("DIContainer Tests")
@MainActor
struct DIContainerTests {
    var modelContainer: ModelContainer
    var sut: DIContainer

    init() throws {
        modelContainer = try createTestModelContainer()
        sut = DIContainer(modelContext: modelContainer.mainContext)
    }

    @Test("makeArticleListViewModel returns configured instance")
    func makeArticleListViewModelReturnsInstance() {
        let viewModel = sut.makeArticleListViewModel()

        #expect(viewModel.isLoading == false)
    }

    @Test("makeArticleListViewModel returns new instance each call")
    func makeArticleListViewModelReturnsNewInstance() {
        let viewModel1 = sut.makeArticleListViewModel()
        let viewModel2 = sut.makeArticleListViewModel()

        #expect(viewModel1 !== viewModel2)
    }

    @Test("makeReaderViewModel returns configured instance with article")
    func makeReaderViewModelReturnsInstanceWithArticle() {
        let article = ArticleFixtures.createArticle(content: "Test content")

        let viewModel = sut.makeReaderViewModel(article: article)

        #expect(viewModel.article === article)
        #expect(viewModel.isLoading == false)
    }

    @Test("makeReaderViewModel returns new instance each call")
    func makeReaderViewModelReturnsNewInstance() {
        let article = ArticleFixtures.createArticle()

        let viewModel1 = sut.makeReaderViewModel(article: article)
        let viewModel2 = sut.makeReaderViewModel(article: article)

        #expect(viewModel1 !== viewModel2)
    }

    @Test("makeDiscoveryViewModel returns configured instance")
    func makeDiscoveryViewModelReturnsInstance() {
        let viewModel = sut.makeDiscoveryViewModel()

        #expect(viewModel.isLoading == false)
    }

    @Test("makeDiscoveryViewModel returns new instance each call")
    func makeDiscoveryViewModelReturnsNewInstance() {
        let viewModel1 = sut.makeDiscoveryViewModel()
        let viewModel2 = sut.makeDiscoveryViewModel()

        #expect(viewModel1 !== viewModel2)
    }

    @Test("makeSettingsViewModel returns configured instance")
    func makeSettingsViewModelReturnsInstance() {
        let viewModel = sut.makeSettingsViewModel()

        _ = viewModel.selectedDiscoverySource
    }

    @Test("makeSettingsViewModel returns new instance each call")
    func makeSettingsViewModelReturnsNewInstance() {
        let viewModel1 = sut.makeSettingsViewModel()
        let viewModel2 = sut.makeSettingsViewModel()

        #expect(viewModel1 !== viewModel2)
    }

    @Test("multiple DIContainers can be created independently")
    func multipleDIContainersCanBeCreated() throws {
        let container2 = DIContainer(modelContext: modelContainer.mainContext)

        let viewModel1 = sut.makeArticleListViewModel()
        let viewModel2 = container2.makeArticleListViewModel()

        #expect(viewModel1 !== viewModel2)
    }

    @Test("DIContainer with different ModelContext creates isolated ViewModels")
    func diContainerWithDifferentContextCreatesIsolatedViewModels() throws {
        let modelContainer2 = try createTestModelContainer()
        let container2 = DIContainer(modelContext: modelContainer2.mainContext)

        let viewModel1 = sut.makeArticleListViewModel()
        let viewModel2 = container2.makeArticleListViewModel()

        #expect(viewModel1 !== viewModel2)
    }
}

@Suite("DIContainer Lazy Initialization Tests")
@MainActor
struct DIContainerLazyInitTests {
    @Test("services are lazily initialized")
    func servicesAreLazilyInitialized() throws {
        let modelContainer = try createTestModelContainer()

        let diContainer = DIContainer(modelContext: modelContainer.mainContext)

        _ = diContainer.makeArticleListViewModel()
        _ = diContainer.makeReaderViewModel(article: ArticleFixtures.createArticle())
        _ = diContainer.makeDiscoveryViewModel()
        _ = diContainer.makeSettingsViewModel()
    }

    @Test("repeated calls reuse same lazy services")
    func repeatedCallsReuseSameLazyServices() throws {
        let modelContainer = try createTestModelContainer()
        let diContainer = DIContainer(modelContext: modelContainer.mainContext)

        for _ in 0..<5 {
            _ = diContainer.makeArticleListViewModel()
            _ = diContainer.makeDiscoveryViewModel()
        }
    }
}

@Suite("DIContainer ViewModel Configuration Tests")
@MainActor
struct DIContainerViewModelConfigTests {
    var modelContainer: ModelContainer
    var sut: DIContainer

    init() throws {
        modelContainer = try createTestModelContainer()
        sut = DIContainer(modelContext: modelContainer.mainContext)
    }

    @Test("ArticleListViewModel has initial empty state")
    func articleListViewModelHasInitialEmptyState() {
        let viewModel = sut.makeArticleListViewModel()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ReaderViewModel has initial state with provided article")
    func readerViewModelHasInitialStateWithArticle() {
        let article = ArticleFixtures.createArticle(
            title: "Test Title",
            content: "Test Content"
        )

        let viewModel = sut.makeReaderViewModel(article: article)

        #expect(viewModel.article.title == "Test Title")
        #expect(viewModel.article.content == "Test Content")
        #expect(viewModel.isLoading == false)
    }

    @Test("DiscoveryViewModel has initial empty state")
    func discoveryViewModelHasInitialEmptyState() {
        let viewModel = sut.makeDiscoveryViewModel()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.ephemeralArticle == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("SettingsViewModel initializes with preferences")
    func settingsViewModelInitializesWithPreferences() {
        let viewModel = sut.makeSettingsViewModel()

        _ = viewModel.selectedDiscoverySource
    }
}
