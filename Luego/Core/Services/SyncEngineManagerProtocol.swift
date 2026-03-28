import CloudKit
import Foundation

@MainActor
protocol SyncEngineManagerProtocol: AnyObject {
    var state: SyncState { get }
    var lastSyncTime: Date? { get }
    func start() throws
    func enqueueSave(for recordID: CKRecord.ID)
    func enqueueDelete(for recordID: CKRecord.ID)
    func fetchChanges() async
    func dismissError()
}
