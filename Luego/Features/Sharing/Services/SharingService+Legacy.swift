import SwiftData

extension SharingService {
    convenience init(
        modelContext _: ModelContext,
        metadataDataSource: MetadataDataSourceProtocol,
        userDefaultsDataSource: UserDefaultsDataSourceProtocol
    ) {
        self.init(
            articleStore: GRDBArticleStore(database: try! AppDatabase.makeDefault()),
            metadataDataSource: metadataDataSource,
            userDefaultsDataSource: userDefaultsDataSource
        )
    }
}
