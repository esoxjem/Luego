import Foundation
import SwiftData

@MainActor
final class DIContainer {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private lazy var userDefaultsDataSource: UserDefaultsDataSource = {
        UserDefaultsDataSource()
    }()

    private lazy var turndownDataSource: TurndownDataSource = {
        TurndownDataSource()
    }()

    private lazy var articleRepository: ArticleRepositoryProtocol = {
        ArticleRepository(modelContext: modelContext)
    }()

    private lazy var metadataRepository: MetadataRepositoryProtocol = {
        MetadataRepository(turndownDataSource: turndownDataSource)
    }()

    private lazy var sharedStorageRepository: SharedStorageRepositoryProtocol = {
        SharedStorageRepository(userDefaultsDataSource: userDefaultsDataSource)
    }()

    private lazy var addArticleUseCase: AddArticleUseCaseProtocol = {
        AddArticleUseCase(
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    private lazy var getArticlesUseCase: GetArticlesUseCaseProtocol = {
        GetArticlesUseCase(articleRepository: articleRepository)
    }()

    private lazy var deleteArticleUseCase: DeleteArticleUseCaseProtocol = {
        DeleteArticleUseCase(articleRepository: articleRepository)
    }()

    private lazy var fetchArticleContentUseCase: FetchArticleContentUseCaseProtocol = {
        FetchArticleContentUseCase(
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    private lazy var updateArticleReadPositionUseCase: UpdateArticleReadPositionUseCaseProtocol = {
        UpdateArticleReadPositionUseCase(articleRepository: articleRepository)
    }()

    private lazy var syncSharedArticlesUseCase: SyncSharedArticlesUseCaseProtocol = {
        SyncSharedArticlesUseCase(
            sharedStorageRepository: sharedStorageRepository,
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    private lazy var toggleFavoriteUseCase: ToggleFavoriteUseCaseProtocol = {
        ToggleFavoriteUseCase(articleRepository: articleRepository)
    }()

    private lazy var toggleArchiveUseCase: ToggleArchiveUseCaseProtocol = {
        ToggleArchiveUseCase(articleRepository: articleRepository)
    }()

    func makeArticleListViewModel() -> ArticleListViewModel {
        ArticleListViewModel(
            getArticlesUseCase: getArticlesUseCase,
            addArticleUseCase: addArticleUseCase,
            deleteArticleUseCase: deleteArticleUseCase,
            syncSharedArticlesUseCase: syncSharedArticlesUseCase,
            toggleFavoriteUseCase: toggleFavoriteUseCase,
            toggleArchiveUseCase: toggleArchiveUseCase
        )
    }

    func makeReaderViewModel(article: Article) -> ReaderViewModel {
        ReaderViewModel(
            article: article,
            fetchContentUseCase: fetchArticleContentUseCase,
            updateReadPositionUseCase: updateArticleReadPositionUseCase
        )
    }
}
