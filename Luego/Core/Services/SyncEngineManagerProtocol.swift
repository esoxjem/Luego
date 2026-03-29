import CloudKit
import Foundation

@MainActor
protocol SyncEngineManagerProtocol: AnyObject {
    var state: SyncState { get }
    var lastSyncTime: Date? { get }
    func start() throws
    func enqueueSave(for recordID: CKRecord.ID)
    func enqueueDelete(for recordID: CKRecord.ID)
    func fetchChanges() async throws
    func sendChanges() async throws
    func resetSyncStateForFullRefetch() async throws
    func backfillAllArticlesFromServer() async throws -> Int
    func logWatchedRecordSummary(context: String)
    func dismissError()
}
