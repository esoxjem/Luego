import SwiftData

extension ArticleService {
    convenience init(
        modelContext _: ModelContext,
        metadataDataSource: MetadataDataSourceProtocol
    ) {
        let database = try! AppDatabase.makeDefault()
        let articleStore = GRDBArticleStore(database: database)
        let syncEngineManager = SyncEngineManager(database: database, store: articleStore)
        articleStore.syncEngineManager = syncEngineManager
        try? syncEngineManager.start()
        self.init(
            articleStore: articleStore,
            metadataDataSource: metadataDataSource,
            syncEngineManager: syncEngineManager
        )
    }
}
