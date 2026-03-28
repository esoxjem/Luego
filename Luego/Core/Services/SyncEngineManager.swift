import CloudKit
import Foundation
import GRDB
import Observation

extension Notification.Name {
    static let luegoSyncEngineStatusDidChange = Notification.Name("com.esoxjem.Luego.syncEngineStatusDidChange")
}

enum SyncEngineStatusPayloadKey {
    static let state = "state"
    static let lastSyncTime = "lastSyncTime"
    static let errorMessage = "errorMessage"
    static let needsSignIn = "needsSignIn"
    static let accountStatus = "accountStatus"
    static let diagnosticHint = "diagnosticHint"
    static let cloudKitContainerIdentifier = "cloudKitContainerIdentifier"
    static let cloudKitIdentityTokenState = "cloudKitIdentityTokenState"
    static let cloudKitUserRecordID = "cloudKitUserRecordID"
    static let recentFailedSaveDetails = "recentFailedSaveDetails"
}

@Observable
@MainActor
final class SyncEngineManager: SyncEngineManagerProtocol {
    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    @ObservationIgnored
    private let database: AppDatabase

    @ObservationIgnored
    private let store: ArticleStoreProtocol

    @ObservationIgnored
    private let container: CKContainer

    @ObservationIgnored
    private var syncEngine: CKSyncEngine?

    @ObservationIgnored
    private var idleTask: Task<Void, Never>?

    @ObservationIgnored
    private var currentStateSerialization: CKSyncEngine.State.Serialization?

    @ObservationIgnored
    private var recentFailedSaveDetails: [String] = []

    init(
        database: AppDatabase,
        store: ArticleStoreProtocol? = nil,
        container: CKContainer = CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier)
    ) {
        self.database = database
        self.store = store ?? GRDBArticleStore(database: database)
        self.container = container
    }

    func start() throws {
        guard syncEngine == nil else { return }

        let payload = try database.syncEngineStatePayload()
        lastSyncTime = payload?.lastSyncTime
        currentStateSerialization = payload?.stateSerialization

        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: payload?.stateSerialization,
            delegate: self
        )
        syncEngine = CKSyncEngine(configuration)
        publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        let currentState = state
        let currentLastSyncTime = lastSyncTime
        let cloudKitContainer = container
        Task {
            let diagnostics = await CloudKitRuntimeDiagnostics.collect(
                container: cloudKitContainer,
                containerIdentifier: AppConfiguration.cloudKitContainerIdentifier
            )
            Logger.cloudKit.info("Launch diagnostics — \(diagnostics.summaryLine)")
            for line in diagnostics.detailLines {
                Logger.cloudKit.info("Launch diagnostics — \(line)")
            }
            publishStatus(
                currentState,
                lastSyncTime: currentLastSyncTime,
                errorMessage: nil,
                needsSignIn: diagnostics.needsSignIn,
                accountStatus: diagnostics.accountStatus,
                diagnosticHint: diagnostics.actionableHint,
                cloudKitContainerIdentifier: diagnostics.containerIdentifier,
                cloudKitIdentityTokenState: diagnostics.identityTokenState,
                cloudKitUserRecordID: diagnostics.userRecordID
            )
        }
    }

    func enqueueSave(for recordID: CKRecord.ID) {
        syncEngine?.state.add(
            pendingRecordZoneChanges: [.saveRecord(recordID)]
        )
        publishStatus(.syncing, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func enqueueDelete(for recordID: CKRecord.ID) {
        syncEngine?.state.add(
            pendingRecordZoneChanges: [.deleteRecord(recordID)]
        )
        publishStatus(.syncing, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func fetchChanges() async {
        guard let syncEngine else { return }

        publishStatus(.syncing, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)

        do {
            try await syncEngine.fetchChanges()
        } catch {
            Logger.cloudKit.error("Fetch changes failed: \(error.localizedDescription)")
            let diagnostics = await CloudKitRuntimeDiagnostics.collect(
                container: container,
                containerIdentifier: AppConfiguration.cloudKitContainerIdentifier
            )
            Logger.cloudKit.info("Fetch changes diagnostics — \(diagnostics.summaryLine)")
            for line in diagnostics.detailLines {
                Logger.cloudKit.info("Fetch changes diagnostics — \(line)")
            }
            publishStatus(
                .error(message: diagnostics.actionableHint, needsSignIn: diagnostics.needsSignIn),
                lastSyncTime: lastSyncTime,
                errorMessage: diagnostics.actionableHint,
                needsSignIn: diagnostics.needsSignIn,
                accountStatus: diagnostics.accountStatus,
                diagnosticHint: diagnostics.actionableHint,
                cloudKitContainerIdentifier: diagnostics.containerIdentifier,
                cloudKitIdentityTokenState: diagnostics.identityTokenState,
                cloudKitUserRecordID: diagnostics.userRecordID
            )
        }
    }

    func dismissError() {
        if case .error = state {
            publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        }
    }
}

extension SyncEngineManager: CKSyncEngineDelegate {
    func handleEvent(
        _ event: CKSyncEngine.Event,
        syncEngine: CKSyncEngine
    ) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            await persistStateSerialization(stateUpdate.stateSerialization)
        case .fetchedRecordZoneChanges(let changes):
            await processFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            await processSentRecordZoneChanges(sent, syncEngine: syncEngine)
        case .accountChange(let change):
            handleAccountChange(change)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges
            .filter { context.options.scope.contains($0) }

        let recordsByID = Dictionary(uniqueKeysWithValues: pendingChanges.compactMap { change -> (CKRecord.ID, ArticleRecord)? in
            guard case .saveRecord(let recordID) = change else {
                return nil
            }

            guard let record = try? store.fetchRecord(recordName: recordID.recordName) else {
                syncEngine.state.remove(
                    pendingRecordZoneChanges: [.saveRecord(recordID)]
                )
                return nil
            }

            return (recordID, record)
        })

        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: pendingChanges
        ) { recordID in
            recordsByID[recordID]?.makeCKRecord(recordID: recordID)
        }
    }
}

private extension SyncEngineManager {
    func processFetchedRecordZoneChanges(
        _ changes: CKSyncEngine.Event.FetchedRecordZoneChanges
    ) async {
        var didFail = false

        for modification in changes.modifications {
            do {
                try await processIncomingRecord(modification.record)
            } catch {
                didFail = true
                Logger.cloudKit.error(
                    "Failed to process record \(modification.record.recordID.recordName): \(error.localizedDescription)"
                )
            }
        }

        for deletion in changes.deletions {
            do {
                try await processIncomingDeletion(deletion.recordID)
            } catch {
                didFail = true
                Logger.cloudKit.error(
                    "Failed to process deletion \(deletion.recordID.recordName): \(error.localizedDescription)"
                )
            }
        }

        if didFail {
            publishStatus(.error(message: "Unable to apply changes from iCloud", needsSignIn: false), lastSyncTime: lastSyncTime, errorMessage: "Unable to apply changes from iCloud", needsSignIn: false, accountStatus: nil)
        } else {
            markSyncSuccess()
        }
    }

    func processIncomingRecord(_ record: CKRecord) async throws {
        guard record.recordType == ArticleRecord.recordType else { return }
        try store.saveRecord(try ArticleRecord(record: record))
    }

    func processIncomingDeletion(_ recordID: CKRecord.ID) async throws {
        try store.deleteRecord(recordName: recordID.recordName)
        syncEngine?.state.remove(
            pendingRecordZoneChanges: [.saveRecord(recordID), .deleteRecord(recordID)]
        )
    }

    func processSentRecordZoneChanges(
        _ sent: CKSyncEngine.Event.SentRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) async {
        var didFail = false

        for savedRecord in sent.savedRecords {
            await updateSystemFields(for: savedRecord)
        }

        for failedSave in sent.failedRecordSaves {
            if await handleSendFailure(failedSave, syncEngine: syncEngine) {
                didFail = true
            }
        }

        if didFail {
            publishStatus(.error(message: "Unable to sync with iCloud", needsSignIn: false), lastSyncTime: lastSyncTime, errorMessage: "Unable to sync with iCloud", needsSignIn: false, accountStatus: nil)
        } else {
            markSyncSuccess()
        }
    }

    func updateSystemFields(for record: CKRecord) async {
        do {
            guard let articleID = UUID(uuidString: record.recordID.recordName),
                  var articleRecord = try store.fetchRecord(id: articleID) else {
                return
            }

            articleRecord.cloudKitSystemFields = ArticleRecord.encodeSystemFields(record)
            try store.saveRecord(articleRecord)
        } catch {
            Logger.cloudKit.error(
                "Failed to update system fields for \(record.recordID.recordName): \(error.localizedDescription)"
            )
        }
    }

    func handleSendFailure(
        _ failedSave: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        syncEngine: CKSyncEngine
    ) async -> Bool {
        let ckError = failedSave.error
        let recordID = failedSave.record.recordID
        let storedRecord = try? store.fetchRecord(recordName: recordID.recordName)
        let recordContext = recordDiagnosticsContext(
            for: failedSave.record,
            storedRecord: storedRecord ?? nil
        )

        if ckError.code == .serverRecordChanged,
           let serverRecord = ckError.serverRecord {
            Logger.cloudKit.warning(
                "Resolved serverRecordChanged for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) context=\(recordContext)"
            )
            do {
                try await processIncomingRecord(serverRecord)
                return false
            } catch {
                Logger.cloudKit.error(
                    "Failed to apply server record during conflict resolution for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                appendRecentFailedSaveDetail(
                    "Conflict resolution failed for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                return true
            }
        }

        if shouldTreatMissingServerRecordAsRemoteDeletion(
            error: ckError,
            storedRecord: storedRecord
        ) {
            let detail = [
                "Remote deletion detected for local record \(recordID.recordName)",
                "zone=\(recordZoneDescription(for: recordID))",
                "action=deletedLocalCopy",
                recordContext
            ].joined(separator: " | ")
            Logger.cloudKit.warning(detail)
            appendRecentFailedSaveDetail(detail)

            do {
                try store.deleteRecord(recordName: recordID.recordName)
                syncEngine.state.remove(
                    pendingRecordZoneChanges: [.saveRecord(recordID), .deleteRecord(recordID)]
                )
                return false
            } catch {
                Logger.cloudKit.error(
                    "Failed to delete local record after remote deletion detection for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                appendRecentFailedSaveDetail(
                    "Remote deletion recovery failed for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                return true
            }
        }

        let topLevelLine = structuredFailureLine(
            recordID: recordID,
            error: ckError,
            context: recordContext,
            prefix: "Failed to save record"
        )
        Logger.cloudKit.error(topLevelLine)
        appendRecentFailedSaveDetail(topLevelLine)

        if ckError.code == .partialFailure {
            let partialErrors = partialErrorsByRecordID(from: ckError)
            if partialErrors.isEmpty {
                Logger.cloudKit.error(
                    "Partial failure for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) had no itemized suberrors"
                )
            } else {
                for (partialRecordID, partialError) in partialErrors.sorted(by: { $0.0.recordName < $1.0.recordName }) {
                    let partialLine = structuredFailureLine(
                        recordID: partialRecordID,
                        error: partialError,
                        context: recordContext,
                        prefix: "Partial failure item"
                    )
                    Logger.cloudKit.error(partialLine)
                    appendRecentFailedSaveDetail(partialLine)

                    if let partialCKError = partialError as? CKError,
                       partialCKError.code == .partialFailure {
                        let nestedPartialErrors = partialErrorsByRecordID(from: partialCKError)
                        for (nestedRecordID, nestedError) in nestedPartialErrors.sorted(by: { $0.0.recordName < $1.0.recordName }) {
                            let nestedLine = structuredFailureLine(
                                recordID: nestedRecordID,
                                error: nestedError,
                                context: recordContext,
                                prefix: "Nested partial failure item"
                            )
                            Logger.cloudKit.error(nestedLine)
                            appendRecentFailedSaveDetail(nestedLine)
                        }
                    }
                }
            }
        }

        return true
    }

    func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: "signed in")
        case .signOut:
            publishStatus(.error(message: "Sign in to iCloud to sync", needsSignIn: true), lastSyncTime: lastSyncTime, errorMessage: "Sign in to iCloud to sync", needsSignIn: true, accountStatus: "signed out")
        case .switchAccounts:
            publishStatus(.error(message: "iCloud account changed", needsSignIn: true), lastSyncTime: lastSyncTime, errorMessage: "iCloud account changed", needsSignIn: true, accountStatus: "switched accounts")
        @unknown default:
            publishStatus(.error(message: "iCloud account changed", needsSignIn: false), lastSyncTime: lastSyncTime, errorMessage: "iCloud account changed", needsSignIn: false, accountStatus: "unknown")
        }
    }

    func markSyncSuccess() {
        lastSyncTime = Date()
        publishStatus(.success, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if state == .success {
                publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
            }
        }

        Task {
            await persistCurrentSyncState()
        }
    }

    func updateState(_ newState: SyncState) {
        publishStatus(newState, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func publishStatus(
        _ newState: SyncState,
        lastSyncTime: Date?,
        errorMessage: String?,
        needsSignIn: Bool,
        accountStatus: String?,
        diagnosticHint: String? = nil,
        cloudKitContainerIdentifier: String? = nil,
        cloudKitIdentityTokenState: String? = nil,
        cloudKitUserRecordID: String? = nil
    ) {
        state = newState
        NotificationCenter.default.post(
            name: .luegoSyncEngineStatusDidChange,
            object: self,
            userInfo: [
                SyncEngineStatusPayloadKey.state: newState,
                SyncEngineStatusPayloadKey.lastSyncTime: lastSyncTime as Any,
                SyncEngineStatusPayloadKey.errorMessage: errorMessage as Any,
                SyncEngineStatusPayloadKey.needsSignIn: needsSignIn,
                SyncEngineStatusPayloadKey.accountStatus: accountStatus as Any,
                SyncEngineStatusPayloadKey.diagnosticHint: diagnosticHint as Any,
                SyncEngineStatusPayloadKey.cloudKitContainerIdentifier: cloudKitContainerIdentifier as Any,
                SyncEngineStatusPayloadKey.cloudKitIdentityTokenState: cloudKitIdentityTokenState as Any,
                SyncEngineStatusPayloadKey.cloudKitUserRecordID: cloudKitUserRecordID as Any,
                SyncEngineStatusPayloadKey.recentFailedSaveDetails: recentFailedSaveDetails as Any
            ]
        )
    }

    func persistStateSerialization(_ serialization: CKSyncEngine.State.Serialization) async {
        currentStateSerialization = serialization
        await persistSyncState(serialization: serialization, updateLastSyncTime: false)
    }

    func persistCurrentSyncState() async {
        await persistSyncState(serialization: currentStateSerialization, updateLastSyncTime: true)
    }

    func persistSyncState(
        serialization: CKSyncEngine.State.Serialization?,
        updateLastSyncTime: Bool
    ) async {
        do {
            var payload = (try? database.syncEngineStatePayload()) ?? SyncEngineStatePayload()
            payload.stateSerialization = serialization ?? payload.stateSerialization
            if updateLastSyncTime {
                payload.lastSyncTime = lastSyncTime
            }
            try database.saveSyncEngineStatePayload(payload)
        } catch {
            Logger.cloudKit.error("Failed to persist sync state: \(error.localizedDescription)")
        }
    }

    func appendRecentFailedSaveDetail(_ detail: String) {
        guard !detail.isEmpty else { return }
        recentFailedSaveDetails.removeAll { $0 == detail }
        recentFailedSaveDetails.insert(detail, at: 0)
        if recentFailedSaveDetails.count > 5 {
            recentFailedSaveDetails = Array(recentFailedSaveDetails.prefix(5))
        }
    }

    func recordZoneDescription(for recordID: CKRecord.ID) -> String {
        "\(recordID.zoneID.zoneName) owner=\(recordID.zoneID.ownerName)"
    }

    func recordPayloadSummary(record: CKRecord, storedRecord: ArticleRecord?) -> String {
        let urlString = (record["url"] as? String) ?? storedRecord?.url.absoluteString ?? "missing"
        let title = (record["title"] as? String) ?? storedRecord?.title ?? ""
        let content = (record["content"] as? String) ?? storedRecord?.content ?? ""
        let author = (record["author"] as? String) ?? storedRecord?.author ?? ""
        let wordCount = (record["wordCount"] as? Int) ?? storedRecord?.wordCount
        let readPosition = (record["readPosition"] as? Double) ?? storedRecord?.readPosition ?? 0
        let isFavorite = (record["isFavorite"] as? Bool) ?? storedRecord?.isFavorite ?? false
        let isArchived = (record["isArchived"] as? Bool) ?? storedRecord?.isArchived ?? false
        let thumbnailPresent = (record["thumbnailURL"] as? String) != nil || storedRecord?.thumbnailURL != nil
        let publishedDatePresent = (record["publishedDate"] as? Date) != nil || storedRecord?.publishedDate != nil
        let systemFieldsState = storedRecord.map { $0.cloudKitSystemFields == nil ? "absent" : "present" } ?? "unknown"

        return [
            "url=\(urlString)",
            "titleChars=\(title.count)",
            "contentChars=\(content.count)",
            "authorChars=\(author.count)",
            "wordCount=\(wordCount.map { String($0) } ?? "nil")",
            "readPosition=\(readPosition)",
            "isFavorite=\(isFavorite)",
            "isArchived=\(isArchived)",
            "thumbnailURL=\(thumbnailPresent ? "present" : "absent")",
            "publishedDate=\(publishedDatePresent ? "present" : "absent")",
            "cloudKitSystemFields=\(systemFieldsState)"
        ].joined(separator: " | ")
    }

    func structuredFailureLine(
        recordID: CKRecord.ID,
        error: Error,
        context: String,
        prefix: String
    ) -> String {
        let nsError = error as NSError
        let retryAfterSeconds = retryAfterSeconds(for: nsError)
        let errorSummary = "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
        let retrySummary = retryAfterSeconds.map { "retryAfterSeconds=\($0)" } ?? "retryAfterSeconds=nil"

        return [
            "\(prefix) \(recordID.recordName)",
            "zone=\(recordZoneDescription(for: recordID))",
            "error=\(errorSummary)",
            retrySummary,
            "clientRecord=\(ckRecordPresence(error: error, keyPath: \.clientRecord))",
            "serverRecord=\(ckRecordPresence(error: error, keyPath: \.serverRecord))",
            "ancestorRecord=\(ckRecordPresence(error: error, keyPath: \.ancestorRecord))",
            context
        ].joined(separator: " | ")
    }

    func ckRecordPresence(error: Error, keyPath: KeyPath<CKError, CKRecord?>) -> String {
        guard let ckError = error as? CKError else { return "unknown" }
        return ckError[keyPath: keyPath] == nil ? "absent" : "present"
    }

    func retryAfterSeconds(for error: NSError) -> TimeInterval? {
        if let value = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return value
        }
        if let value = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    func partialErrorsByRecordID(from error: CKError) -> [(CKRecord.ID, Error)] {
        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
            return errors.map { ($0.key, $0.value) }
        }

        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            return errors.compactMap { key, value in
                guard let recordID = key as? CKRecord.ID else { return nil }
                return (recordID, value)
            }
        }

        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
            return errors.compactMap { key, value in
                guard let recordID = key as? CKRecord.ID else { return nil }
                guard let nestedError = value as? Error else { return nil }
                return (recordID, nestedError)
            }
        }

        return []
    }

    func describe(error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
    }

    func shouldTreatMissingServerRecordAsRemoteDeletion(
        error: CKError,
        storedRecord: ArticleRecord?
    ) -> Bool {
        error.code == .unknownItem && storedRecord?.cloudKitSystemFields != nil
    }

    func recordDiagnosticsContext(
        for record: CKRecord,
        storedRecord: ArticleRecord?
    ) -> String {
        guard let articleID = UUID(uuidString: record.recordID.recordName) else {
            return "storedRecord=unavailable"
        }

        guard let storedRecord else {
            return "storedRecord=missing id=\(articleID.uuidString)"
        }

        return "storedRecord=present | \(recordPayloadSummary(record: record, storedRecord: storedRecord))"
    }
}
