import Foundation
import SwiftData

@MainActor
final class DIContainer {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private lazy var htmlParserDataSource: HTMLParserDataSource = {
        HTMLParserDataSource()
    }()

    private lazy var userDefaultsDataSource: UserDefaultsDataSource = {
        UserDefaultsDataSource()
    }()

    private lazy var articleRepository: ArticleRepositoryProtocol = {
        ArticleRepository(modelContext: modelContext)
    }()

    private lazy var metadataRepository: MetadataRepositoryProtocol = {
        MetadataRepository(htmlParser: htmlParserDataSource)
    }()

    private lazy var sharedStorageRepository: SharedStorageRepositoryProtocol = {
        SharedStorageRepository(userDefaultsDataSource: userDefaultsDataSource)
    }()

    private lazy var addArticleUseCase: AddArticleUseCase = {
        DefaultAddArticleUseCase(
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    private lazy var getArticlesUseCase: GetArticlesUseCase = {
        DefaultGetArticlesUseCase(articleRepository: articleRepository)
    }()

    private lazy var deleteArticleUseCase: DeleteArticleUseCase = {
        DefaultDeleteArticleUseCase(articleRepository: articleRepository)
    }()

    private lazy var fetchArticleContentUseCase: FetchArticleContentUseCase = {
        DefaultFetchArticleContentUseCase(
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    private lazy var updateArticleReadPositionUseCase: UpdateArticleReadPositionUseCase = {
        DefaultUpdateArticleReadPositionUseCase(articleRepository: articleRepository)
    }()

    private lazy var syncSharedArticlesUseCase: SyncSharedArticlesUseCase = {
        DefaultSyncSharedArticlesUseCase(
            sharedStorageRepository: sharedStorageRepository,
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    func makeArticleListViewModel() -> ArticleListViewModel {
        ArticleListViewModel(
            getArticlesUseCase: getArticlesUseCase,
            addArticleUseCase: addArticleUseCase,
            deleteArticleUseCase: deleteArticleUseCase,
            syncSharedArticlesUseCase: syncSharedArticlesUseCase
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
