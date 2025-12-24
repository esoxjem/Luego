import Foundation
import SwiftData

@MainActor
final class DIContainer {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private lazy var userDefaultsDataSource: UserDefaultsDataSourceProtocol = {
        UserDefaultsDataSource(sharedStorage: SharedStorage.shared)
    }()

    private lazy var turndownDataSource: TurndownDataSource = {
        TurndownDataSource()
    }()

    private lazy var metadataDataSource: MetadataDataSourceProtocol = {
        MetadataDataSource(turndownDataSource: turndownDataSource)
    }()

    private lazy var opmlDataSource: OPMLDataSource = {
        OPMLDataSource()
    }()

    private lazy var blogrollRSSDataSource: BlogrollRSSDataSource = {
        BlogrollRSSDataSource()
    }()

    private lazy var genericRSSDataSource: GenericRSSDataSource = {
        GenericRSSDataSource()
    }()

    private lazy var kagiSmallWebDataSource: DiscoverySourceProtocol = {
        KagiSmallWebDataSource(opmlDataSource: opmlDataSource)
    }()

    private lazy var blogrollDataSource: DiscoverySourceProtocol = {
        BlogrollDataSource(
            blogrollRSSDataSource: blogrollRSSDataSource,
            genericRSSDataSource: genericRSSDataSource
        )
    }()

    private lazy var discoveryPreferencesDataSource: DiscoveryPreferencesDataSourceProtocol = {
        DiscoveryPreferencesDataSource()
    }()

    private lazy var articleService: ArticleServiceProtocol = {
        ArticleService(
            modelContext: modelContext,
            metadataDataSource: metadataDataSource
        )
    }()

    private lazy var readerService: ReaderServiceProtocol = {
        ReaderService(
            modelContext: modelContext,
            metadataDataSource: metadataDataSource
        )
    }()

    private lazy var discoveryService: DiscoveryServiceProtocol = {
        DiscoveryService(
            kagiSmallWebDataSource: kagiSmallWebDataSource,
            blogrollDataSource: blogrollDataSource,
            metadataDataSource: metadataDataSource
        )
    }()

    private lazy var sharingService: SharingServiceProtocol = {
        SharingService(
            modelContext: modelContext,
            metadataDataSource: metadataDataSource,
            userDefaultsDataSource: userDefaultsDataSource
        )
    }()

    func makeArticleListViewModel() -> ArticleListViewModel {
        ArticleListViewModel(
            articleService: articleService,
            sharingService: sharingService
        )
    }

    func makeReaderViewModel(article: Article) -> ReaderViewModel {
        ReaderViewModel(
            article: article,
            readerService: readerService
        )
    }

    func makeDiscoveryViewModel() -> DiscoveryViewModel {
        DiscoveryViewModel(
            discoveryService: discoveryService,
            articleService: articleService,
            preferencesDataSource: discoveryPreferencesDataSource
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            preferencesDataSource: discoveryPreferencesDataSource,
            discoveryService: discoveryService
        )
    }
}
