import SwiftData

extension ArticleService {
    convenience init(
        modelContext _: ModelContext,
        metadataDataSource: MetadataDataSourceProtocol
    ) {
        self.init(
            articleStore: GRDBArticleStore(database: try! AppDatabase.makeDefault()),
            metadataDataSource: metadataDataSource
        )
    }
}
