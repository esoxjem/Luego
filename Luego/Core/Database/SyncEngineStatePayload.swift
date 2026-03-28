import CloudKit
import Foundation

struct SyncEngineStatePayload: Codable {
    var stateSerialization: CKSyncEngine.State.Serialization?
    var lastSyncTime: Date?
}
